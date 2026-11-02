# Keycloak realm, imported once at the first start (start-dev --import-realm).
# Unlike Dex, Keycloak has real groups: the "groups" protocol mapper on the
# semaphore client puts the user's group names into id/access/userinfo tokens
# under the "groups" claim, no extra scope needed.
locals {
  keycloak_realm = "bookwright"

  # Stand values, not integration-tests fixtures (there is no Keycloak profile
  # there). kc-admin-conflict mirrors the Dex/LDAP conflict users.
  keycloak_users = [
    {
      username   = "kc.user"
      email      = "kc.user@bookwright.test"
      first_name = "Keycloak"
      last_name  = "User"
      password   = "Bookwright-KC-42!"
    },
    {
      username   = "kc-admin-conflict"
      email      = "admin@localhost"
      first_name = "Keycloak"
      last_name  = "Conflict"
      password   = "Bookwright-KC-Conflict-42!"
    },
    # Same login and email in every provider of the stand (account matching checks).
    {
      username   = "john.user"
      email      = "john.user@semaphore.test"
      first_name = "John"
      last_name  = "User"
      password   = "John-User-42!"
    },
  ]

  keycloak_groups = ["devops"]

  keycloak_realm_json = jsonencode({
    realm       = local.keycloak_realm
    enabled     = true
    displayName = "Bookwright"
    # TLS ends at Cloudflare; Keycloak itself only ever sees plain HTTP.
    sslRequired = "none"

    groups = [for g in local.keycloak_groups : { name = g }]

    users = [for u in local.keycloak_users : {
      username      = u.username
      email         = u.email
      emailVerified = true
      enabled       = true
      firstName     = u.first_name
      lastName      = u.last_name
      credentials   = [{ type = "password", value = u.password, temporary = false }]
      groups        = [for g in local.keycloak_groups : "/${g}"]
    }]

    clients = [{
      clientId                  = "semaphore"
      name                      = "Semaphore"
      enabled                   = true
      protocol                  = "openid-connect"
      publicClient              = false
      clientAuthenticatorType   = "client-secret"
      secret                    = var.keycloak_client_secret
      standardFlowEnabled       = true
      implicitFlowEnabled       = false
      directAccessGrantsEnabled = false
      redirectUris              = [local.keycloak_redirect_uri]
      protocolMappers = [{
        name            = "groups"
        protocol        = "openid-connect"
        protocolMapper  = "oidc-group-membership-mapper"
        consentRequired = false
        config = {
          "claim.name"           = "groups"
          "full.path"            = "false"
          "id.token.claim"       = "true"
          "access.token.claim"   = "true"
          "userinfo.token.claim" = "true"
        }
      }]
    }]
  })
}
