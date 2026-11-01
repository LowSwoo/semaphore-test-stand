output "urn" {
  description = "Droplet URN, for digitalocean_project_resources."
  value       = digitalocean_droplet.idp.urn
}

output "public_ip" {
  value = digitalocean_droplet.idp.ipv4_address
}

output "private_ip" {
  value = digitalocean_droplet.idp.ipv4_address_private
}

output "dex_issuer" {
  description = "Dex OIDC issuer (= provider_url of oidc_providers.dex); null when Dex is off."
  value       = var.dex_enabled ? local.dex_issuer : null
}

output "semaphore_config" {
  description = "config.yml keys for the enabled providers (ldap_*, oidc_providers), for the semaphore module's extra_config."
  value       = local.semaphore_config
  sensitive   = true
}

output "keycloak_issuer" {
  description = "Keycloak OIDC issuer (= provider_url of oidc_providers.keycloak); null when Keycloak is off."
  value       = var.keycloak_enabled ? local.keycloak_issuer : null
}

output "keycloak_admin_url" {
  description = "Keycloak admin console (login 'admin' / keycloak_admin_password); null when Keycloak is off."
  value       = var.keycloak_enabled ? "https://${local.keycloak_hostname}/admin/" : null
}
