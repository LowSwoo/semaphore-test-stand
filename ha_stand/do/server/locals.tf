locals {
  prefix         = var.prefix != "" ? var.prefix : terraform.workspace
  api_token_path = "/tmp/${local.prefix}-admin.token"
  # S3 location the runner module reads the admin token from.
  s3_bucket          = var.s3_bucket != "" ? var.s3_bucket : "${local.prefix}-semaphore-stand"
  admin_token_s3_key = "${local.prefix}/admin.token"
  lb_hostname        = "${local.prefix}-lb.${var.parent_domain}"
  web_root           = "https://${local.lb_hostname}"
  api_base_url       = "${local.web_root}/api"
  config             = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))

  # Redis Sentinel cluster shape. Optional in config.yml so existing stands keep working.
  redis_nodes           = lookup(local.config, "redis_nodes", 2)
  redis_sentinel_quorum = lookup(local.config, "redis_sentinel_quorum", 1)
  redis_master_name     = lookup(local.config, "redis_master_name", "semaphore")

  # All Sentinel endpoints (master first), handed to the Semaphore nodes as ha.redis_sentinel.addrs.
  redis_private_ips    = concat([digitalocean_droplet.redis_master.ipv4_address_private], digitalocean_droplet.redis_replica[*].ipv4_address_private)
  redis_sentinel_addrs = [for ip in local.redis_private_ips : "${ip}:26379"]

  # Identity providers (SSO stand): OpenLDAP and/or Dex on one "idp" droplet,
  # switched on by the optional identity_providers block in config.yml. A missing
  # block or key means false, so stands without it are planned exactly as before.
  ldap_enabled = try(local.config.identity_providers.ldap, false) == true
  dex_enabled  = try(local.config.identity_providers.dex, false) == true
  idp_enabled  = local.ldap_enabled || local.dex_enabled

  # Directory and users come from the integration-tests fixture
  # (profiles/feature-ldap-tls), so the tests run against the stand unchanged.
  ldap_base_dn   = "dc=bookwright,dc=test"
  ldap_bind_dn   = "cn=admin,${local.ldap_base_dn}"
  ldap_search_dn = "ou=people,${local.ldap_base_dn}"

  # Dex is reached by the user's browser, so it gets its own proxied hostname;
  # the Semaphore nodes fetch discovery through the same URL, which is why the
  # issuer is the public https address and not the droplet's private IP.
  dex_hostname = "${local.prefix}-dex.${var.parent_domain}"
  dex_issuer   = "https://${local.dex_hostname}/dex"

  # The fixtures' conflict users (LDAP ldap-admin-conflict, Dex admin@localhost)
  # collide with the local admin by email only when the admin has this address.
  admin_email = local.idp_enabled ? "admin@localhost" : var.semaphore_admin_email
}
