locals {
  prefix      = var.prefix != "" ? var.prefix : terraform.workspace
  ui_hostname = "${local.prefix}-ui.${var.parent_domain}"
  web_root    = "https://${local.ui_hostname}"
  config      = yamldecode(file("${path.module}/../../workspaces/${local.prefix}/config.yml"))

  # All providers are on unless config.yml switches one off.
  ldap_enabled     = try(local.config.identity_providers.ldap, true) == true
  ldap2_enabled    = try(local.config.identity_providers.ldap2, true) == true
  dex_enabled      = try(local.config.identity_providers.dex, true) == true
  keycloak_enabled = try(local.config.identity_providers.keycloak, true) == true

  # The conflict users (LDAP ldap-admin-conflict / marlowe-admin-conflict, Dex
  # admin@localhost, Keycloak kc-admin-conflict) collide with the local admin by email only when the admin has this address.
  admin_email = "admin@localhost"
}
