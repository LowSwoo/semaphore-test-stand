locals {
  # Directory and users come from the integration-tests fixture
  # (profiles/feature-ldap-tls), so the tests run against the stand unchanged.
  ldap_base_dn   = "dc=bookwright,dc=test"
  ldap_bind_dn   = "cn=admin,${local.ldap_base_dn}"
  ldap_search_dn = "ou=people,${local.ldap_base_dn}"

  # Dex is reached by the user's browser, so it gets its own proxied hostname;
  # the Semaphore nodes fetch discovery through the same URL, which is why the
  # issuer is the public https address and not the droplet's private IP.
  dex_hostname = "${var.prefix}-dex.${var.parent_domain}"
  dex_issuer   = "https://${local.dex_hostname}/dex"

  # Keys of Semaphore's config.yml per provider; semaphore_config merges the
  # enabled ones for the semaphore module's extra_config. Kept here so the
  # issuer, client and DNs cannot drift apart from the idp droplet.
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

  oidc_config = {
    oidc_providers = {
      dex = {
        display_name     = "Bookwright Dex"
        provider_url     = local.dex_issuer
        client_id        = "semaphore"
        client_secret    = var.dex_client_secret
        redirect_url     = "${var.semaphore_web_root}/api/auth/oidc/dex/redirect"
        username_claim   = "email"
        name_claim       = "email"
        return_via_state = true
      }
      # Deliberately unreachable provider (integration-tests fixture) for the
      # provider-failure check: its login answers 500.
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
  }

  semaphore_config = merge(concat(
    var.ldap_enabled ? [local.ldap_config] : [],
    var.dex_enabled ? [local.oidc_config] : [],
  )...)
}
