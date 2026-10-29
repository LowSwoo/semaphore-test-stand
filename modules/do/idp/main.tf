# Identity providers for SSO testing: OpenLDAP and/or Dex on one droplet with
# Docker Compose (templates/idp.yaml.tftpl). LDAP and Dex are two independent
# login methods for Semaphore; Dex has no LDAP connector.
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
    ldap_enabled        = var.ldap_enabled
    dex_enabled         = var.dex_enabled
    ldap_base_dn        = local.ldap_base_dn
    ldap_bind_dn        = local.ldap_bind_dn
    ldap_admin_password = var.ldap_admin_password
    ldap_users_ldif     = file("${path.module}/templates/50-bookwright-users.ldif")
    dex_config = templatefile("${path.module}/templates/dex.yaml.tftpl", {
      issuer        = local.dex_issuer
      client_secret = var.dex_client_secret
      redirect_uri  = "${var.semaphore_web_root}/api/auth/oidc/dex/redirect"
    })
  })

  lifecycle {
    precondition {
      condition     = var.ldap_enabled || var.dex_enabled
      error_message = "Enable at least one of ldap_enabled, dex_enabled."
    }
  }
}

# Dex has to be reachable from the user's browser: proxied record, TLS at the
# Cloudflare edge, origin over plain HTTP :80. This relies on the zone's SSL
# mode being Flexible; 525/526 on the discovery URL means the zone setting,
# not the stand.
resource "cloudflare_record" "dex" {
  count   = var.dex_enabled ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "${var.prefix}-dex"
  type    = "A"
  content = digitalocean_droplet.idp.ipv4_address
  proxied = true
  ttl     = 1
}

# Dex is only ever reached through the Cloudflare proxy, so :80 is open to
# Cloudflare's edge ranges rather than the whole internet.
data "cloudflare_ip_ranges" "edge" {
  count = var.dex_enabled ? 1 : 0
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

  # Dex — Cloudflare edge only.
  dynamic "inbound_rule" {
    for_each = var.dex_enabled ? [1] : []
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
