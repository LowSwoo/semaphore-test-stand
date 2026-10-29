locals {
  prefix      = var.prefix != "" ? var.prefix : terraform.workspace
  ui_hostname = "${local.prefix}-ui.${var.parent_domain}"
  web_root    = "https://${local.ui_hostname}"
  config      = yamldecode(file("${path.module}/../../workspaces/${local.prefix}/config.yml"))

  # Both providers are on unless config.yml switches one off.
  ldap_enabled = try(local.config.identity_providers.ldap, true) == true
  dex_enabled  = try(local.config.identity_providers.dex, true) == true

  # The fixtures' conflict users (LDAP ldap-admin-conflict, Dex admin@localhost)
  # collide with the local admin by email only when the admin has this address.
  admin_email = "admin@localhost"
}
