# Identity providers of the SSO stand: OpenLDAP and Dex on one droplet, created
# only when config.yml enables at least one of them (see locals.tf). LDAP and Dex
# are two independent login methods for Semaphore; Dex has no LDAP connector.
#
# Its private IP goes into the user_data of the UI nodes (ldap_server), so
# replacing this droplet replaces all UI nodes and re-mints the admin token;
# re-apply the runner module afterwards.
resource "digitalocean_droplet" "idp" {
  count    = local.idp_enabled ? 1 : 0
  name     = "idp"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [data.digitalocean_ssh_key.default.id]
  # base: the shared firewall (SSH, egress); idp: the LDAP/Dex ports below.
  tags = [digitalocean_tag.base.id, digitalocean_tag.idp[0].id]

  user_data = templatefile("${path.module}/../../shared/cloud-init/idp.yaml.tftpl", {
    ldap_enabled        = local.ldap_enabled
    dex_enabled         = local.dex_enabled
    ldap_base_dn        = local.ldap_base_dn
    ldap_bind_dn        = local.ldap_bind_dn
    ldap_admin_password = var.ldap_admin_password
    ldap_users_ldif     = file("${path.module}/../../shared/idp/50-bookwright-users.ldif")
    dex_config = templatefile("${path.module}/../../shared/idp/dex.yaml.tftpl", {
      issuer        = local.dex_issuer
      client_secret = var.dex_client_secret
      redirect_uri  = "${local.web_root}/api/auth/oidc/dex/redirect"
    })
  })
}

# Dex has to be reachable from the user's browser: proxied record like the LB's,
# TLS at the Cloudflare edge, origin over plain HTTP :80. Like the LB, this relies
# on the zone's SSL mode being Flexible; 525/526 on the discovery URL means the
# zone setting, not the stand.
resource "cloudflare_record" "dex" {
  count   = local.dex_enabled ? 1 : 0
  zone_id = data.cloudflare_zone.parent.id
  name    = "${local.prefix}-dex"
  type    = "A"
  content = digitalocean_droplet.idp[0].ipv4_address
  proxied = true
  ttl     = 1
}

# Dex is only ever reached through the Cloudflare proxy, so :80 is open to
# Cloudflare's edge ranges rather than the whole internet.
data "cloudflare_ip_ranges" "edge" {
  count = local.dex_enabled ? 1 : 0
}

# Ports of the idp droplet only; digitalocean_firewall.main stays untouched so
# stands without identity providers plan exactly as before.
resource "digitalocean_firewall" "idp" {
  count = local.idp_enabled ? 1 : 0
  name  = "${local.prefix}-idp-fw"
  tags  = [digitalocean_tag.idp[0].id]

  # OpenLDAP — VPC only (the Semaphore UI nodes).
  dynamic "inbound_rule" {
    for_each = local.ldap_enabled ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "389"
      source_addresses = [local.config.cluster_ip_range]
    }
  }

  # Dex — Cloudflare edge only.
  dynamic "inbound_rule" {
    for_each = local.dex_enabled ? [1] : []
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
