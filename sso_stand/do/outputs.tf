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
  description = "Identity providers droplet (OpenLDAP + Dex)."
  value = {
    public_ip  = module.idp.public_ip
    private_ip = module.idp.private_ip
  }
}

output "dex_issuer_url" {
  description = "Dex OIDC issuer (= provider_url of oidc_providers.dex); null when Dex is off."
  value       = module.idp.dex_issuer
}
