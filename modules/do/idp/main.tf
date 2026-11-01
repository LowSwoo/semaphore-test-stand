# Identity providers for SSO testing: OpenLDAP, Dex and/or Keycloak on one
# droplet with Docker Compose (templates/idp.yaml.tftpl). They are independent
# login methods for Semaphore; with LDAP on, Dex also gets an LDAP connector so
# the directory users (and their groups) can log in through OIDC. Caddy on :80
# routes the web providers by hostname.
#
# The droplet's private IP goes into the Semaphore nodes' config (ldap_server),
# so replacing it replaces the nodes too.
resource "digitalocean_tag" "idp" {
  name = "${var.prefix}-idp"
}

resource "digitalocean_droplet" "idp" {
  name     = "idp"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = var.vpc_uuid

  ssh_keys = var.ssh_keys
  # var.tags: the stand's shared firewall (SSH, egress); idp: the ports below.
  tags = concat(var.tags, [digitalocean_tag.idp.id])

  user_data = templatefile("${path.module}/templates/idp.yaml.tftpl", {
    ldap_enabled            = var.ldap_enabled
    dex_enabled             = var.dex_enabled
    keycloak_enabled        = var.keycloak_enabled
    web_enabled             = local.web_enabled
    ldap_base_dn            = local.ldap_base_dn
    ldap_bind_dn            = local.ldap_bind_dn
    ldap_admin_password     = var.ldap_admin_password
    ldap_users_ldif         = file("${path.module}/templates/50-bookwright-users.ldif")
    keycloak_hostname       = local.keycloak_hostname
    keycloak_admin_password = var.keycloak_admin_password
    keycloak_realm_json     = local.keycloak_realm_json
    caddyfile = templatefile("${path.module}/templates/Caddyfile.tftpl", {
      dex_enabled       = var.dex_enabled
      keycloak_enabled  = var.keycloak_enabled
      dex_hostname      = local.dex_hostname
      keycloak_hostname = local.keycloak_hostname
    })
    dex_config = templatefile("${path.module}/templates/dex.yaml.tftpl", {
      issuer              = local.dex_issuer
      client_secret       = var.dex_client_secret
      redirect_uri        = "${var.semaphore_web_root}/api/auth/oidc/dex/redirect"
      ldap_enabled        = var.ldap_enabled
      ldap_bind_dn        = local.ldap_bind_dn
      ldap_admin_password = var.ldap_admin_password
      ldap_search_dn      = local.ldap_search_dn
      ldap_groups_dn      = local.ldap_groups_dn
    })
  })

  lifecycle {
    precondition {
      condition     = var.ldap_enabled || var.dex_enabled || var.keycloak_enabled
      error_message = "Enable at least one of ldap_enabled, dex_enabled, keycloak_enabled."
    }
  }
}

# Dex and Keycloak have to be reachable from the user's browser: proxied
# records, TLS at the Cloudflare edge, origin over plain HTTP :80. This relies
# on the zone's SSL mode being Flexible; 525/526 on the discovery URL means the
# zone setting, not the stand.
resource "cloudflare_record" "dex" {
  count   = var.dex_enabled ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "${var.prefix}-dex"
  type    = "A"
  content = digitalocean_droplet.idp.ipv4_address
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "keycloak" {
  count   = var.keycloak_enabled ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "${var.prefix}-kc"
  type    = "A"
  content = digitalocean_droplet.idp.ipv4_address
  proxied = true
  ttl     = 1
}

# The web providers are only ever reached through the Cloudflare proxy, so :80
# is open to Cloudflare's edge ranges rather than the whole internet.
data "cloudflare_ip_ranges" "edge" {
  count = local.web_enabled ? 1 : 0
}

resource "digitalocean_firewall" "idp" {
  name = "${var.prefix}-idp-fw"
  tags = [digitalocean_tag.idp.id]

  # OpenLDAP — VPC only (the Semaphore nodes).
  dynamic "inbound_rule" {
    for_each = var.ldap_enabled ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "389"
      source_addresses = [var.vpc_ip_range]
    }
  }

  # Caddy (Dex, Keycloak) — Cloudflare edge only.
  dynamic "inbound_rule" {
    for_each = local.web_enabled ? [1] : []
    content {
      protocol   = "tcp"
      port_range = "80"
      source_addresses = concat(
        data.cloudflare_ip_ranges.edge[0].ipv4_cidr_blocks,
        data.cloudflare_ip_ranges.edge[0].ipv6_cidr_blocks,
      )
    }
  }
}
