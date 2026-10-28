output "project_id" {
  description = "DigitalOcean project grouping all droplets and the load balancer."
  value       = digitalocean_project.main.id
}

output "semaphore_url" {
  description = "HTTPS entry point for the Semaphore UI."
  value       = local.web_root
}

output "load_balancer_ip" {
  description = "Public IP of the load balancer (HTTP :80, fronted by the Cloudflare proxy)."
  value       = digitalocean_loadbalancer.main.ip
}

output "cluster_servers" {
  description = "Semaphore UI cluster droplets."
  value = {
    for d in digitalocean_droplet.cluster : d.name => {
      region     = d.region
      public_ip  = d.ipv4_address
      private_ip = d.ipv4_address_private
    }
  }
}


output "postgres_server" {
  description = "PostgreSQL droplet."
  value = {
    public_ip  = digitalocean_droplet.postgres.ipv4_address
    private_ip = digitalocean_droplet.postgres.ipv4_address_private
  }
}

output "redis_servers" {
  description = "Redis Sentinel cluster droplets (redis-1 boots as master, the rest as replicas)."
  value = {
    for d in concat([digitalocean_droplet.redis_master], digitalocean_droplet.redis_replica) : d.name => {
      region     = d.region
      public_ip  = d.ipv4_address
      private_ip = d.ipv4_address_private
    }
  }
}

output "redis_sentinel_addrs" {
  description = "Sentinel endpoints (host:port) as configured in Semaphore's ha.redis_sentinel.addrs."
  value       = local.redis_sentinel_addrs
}

output "s3_bucket" {
  description = "S3/R2 bucket carrying the admin token to the runner module."
  value       = aws_s3_bucket.stand.id
}

output "admin_token_s3_uri" {
  description = "S3 URI of the admin API token read by the runner module."
  value       = "s3://${aws_s3_bucket.stand.id}/${aws_s3_object.admin_token.key}"
}

output "idp_server" {
  description = "Identity providers droplet (OpenLDAP + Dex); null without identity_providers in config.yml."
  value = local.idp_enabled ? {
    public_ip  = digitalocean_droplet.idp[0].ipv4_address
    private_ip = digitalocean_droplet.idp[0].ipv4_address_private
  } : null
}

output "dex_issuer_url" {
  description = "Dex OIDC issuer (= provider_url in Semaphore's oidc_providers.dex); null when Dex is disabled."
  value       = local.dex_enabled ? local.dex_issuer : null
}
