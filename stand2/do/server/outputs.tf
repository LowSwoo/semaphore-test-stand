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

output "redis_server" {
  description = "Redis droplet."
  value = {
    public_ip  = digitalocean_droplet.redis.ipv4_address
    private_ip = digitalocean_droplet.redis.ipv4_address_private
  }
}
