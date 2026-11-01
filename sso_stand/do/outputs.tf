output "semaphore_url" {
  description = "HTTPS entry point for the Semaphore UI."
  value       = local.web_root
}

output "semaphore_server" {
  description = "Semaphore droplet."
  value       = module.semaphore.nodes
}

output "postgres_server" {
  description = "PostgreSQL droplet."
  value = {
    public_ip  = module.postgres.public_ip
    private_ip = module.postgres.private_ip
  }
}

output "idp_server" {
  description = "Identity providers droplet (2x OpenLDAP + Dex + Keycloak)."
  value = {
    public_ip  = module.idp.public_ip
    private_ip = module.idp.private_ip
  }
}

output "dex_issuer_url" {
  description = "Dex OIDC issuer (= provider_url of oidc_providers.dex); null when Dex is off."
  value       = module.idp.dex_issuer
}

output "keycloak_issuer_url" {
  description = "Keycloak OIDC issuer (= provider_url of oidc_providers.keycloak); null when Keycloak is off."
  value       = module.idp.keycloak_issuer
}

output "keycloak_admin_url" {
  description = "Keycloak admin console, login 'admin' / TF_VAR_keycloak_admin_password; null when Keycloak is off."
  value       = module.idp.keycloak_admin_url
}
