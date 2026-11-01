locals {
  # Directory and users come from the integration-tests fixture
  # (profiles/feature-ldap-tls), so the tests run against the stand unchanged.
  ldap_base_dn   = "dc=bookwright,dc=test"
  ldap_bind_dn   = "cn=admin,${local.ldap_base_dn}"
  ldap_search_dn = "ou=people,${local.ldap_base_dn}"
  ldap_groups_dn = "ou=groups,${local.ldap_base_dn}"

  # Dex and Keycloak are reached by the user's browser, so each gets its own
  # proxied hostname; the Semaphore nodes fetch discovery through the same URL,
  # which is why the issuers are the public https addresses and not the
  # droplet's private IP. Caddy on :80 routes them by hostname.
  dex_hostname = "${var.prefix}-dex.${var.parent_domain}"
  dex_issuer   = "https://${local.dex_hostname}/dex"

  keycloak_hostname     = "${var.prefix}-kc.${var.parent_domain}"
  keycloak_issuer       = "https://${local.keycloak_hostname}/realms/${local.keycloak_realm}"
  keycloak_redirect_uri = "${var.semaphore_web_root}/api/auth/oidc/keycloak/redirect"

  web_enabled = var.dex_enabled || var.keycloak_enabled

  # Keys of Semaphore's config.yml per provider; semaphore_config merges the
  # enabled ones for the semaphore module's extra_config. Kept here so the
  # issuers, clients and DNs cannot drift apart from the idp droplet.
  ldap_config = {
    ldap_enable       = true
    ldap_server       = "${digitalocean_droplet.idp.ipv4_address_private}:389"
    ldap_needtls      = false
    ldap_binddn       = local.ldap_bind_dn
    ldap_bindpassword = var.ldap_admin_password
    ldap_searchdn     = local.ldap_search_dn
    ldap_searchfilter = "(&(objectClass=inetOrgPerson)(uid=%s))"
    ldap_mappings = {
      dn   = "dn"
      uid  = "uid"
      cn   = "cn"
      mail = "mail"
    }
  }

  dex_provider = {
    dex = {
      display_name  = "Bookwright Dex"
      provider_url  = local.dex_issuer
      client_id     = "semaphore"
      client_secret = var.dex_client_secret
      redirect_url  = "${var.semaphore_web_root}/api/auth/oidc/dex/redirect"
      # groups: Dex puts the LDAP connector's groups into the id_token only
      # when asked for; static users have none (Dex limitation).
      scopes           = ["openid", "profile", "email", "groups"]
      username_claim   = "email"
      name_claim       = "email"
      return_via_state = true
    }
  }

  # No scopes override: the groups claim comes from a mapper on the client
  # itself (keycloak.tf), so the default scopes already carry it.
  keycloak_provider = {
    keycloak = {
      display_name     = "Bookwright Keycloak"
      provider_url     = local.keycloak_issuer
      client_id        = "semaphore"
      client_secret    = var.keycloak_client_secret
      redirect_url     = local.keycloak_redirect_uri
      username_claim   = "email"
      name_claim       = "email"
      return_via_state = true
    }
  }

  # Deliberately unreachable provider (integration-tests fixture) for the
  # provider-failure check: its login answers 500.
  unavailable_provider = {
    unavailable = {
      display_name     = "Unavailable OIDC"
      provider_url     = "http://127.0.0.1:1/oidc"
      client_id        = "unavailable"
      client_secret    = "unavailable-test-client-secret"
      redirect_url     = "${var.semaphore_web_root}/api/auth/oidc/unavailable/redirect"
      username_claim   = "email"
      name_claim       = "email"
      return_via_state = true
    }
  }

  oidc_providers = merge(concat(
    var.dex_enabled ? [local.dex_provider] : [],
    var.keycloak_enabled ? [local.keycloak_provider] : [],
    local.web_enabled ? [local.unavailable_provider] : [],
  )...)

  semaphore_config = merge(concat(
    var.ldap_enabled ? [local.ldap_config] : [],
    local.web_enabled ? [{ oidc_providers = local.oidc_providers }] : [],
  )...)
}
