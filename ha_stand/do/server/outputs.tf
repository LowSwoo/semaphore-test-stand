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
  value       = module.semaphore.nodes
}


output "postgres_server" {
  description = "PostgreSQL droplet."
  value = {
    public_ip  = module.postgres.public_ip
    private_ip = module.postgres.private_ip
  }
}

output "redis_servers" {
  description = "Redis Sentinel cluster droplets (redis-1 boots as master, the rest as replicas)."
  value       = module.redis.servers
}

output "redis_sentinel_addrs" {
  description = "Sentinel endpoints (host:port) as configured in Semaphore's ha.redis_sentinel.addrs."
  value       = module.redis.sentinel_addrs
}

output "s3_bucket" {
  description = "S3/R2 bucket carrying the admin token to the runner module."
  value       = aws_s3_bucket.stand.id
}

output "admin_token_s3_uri" {
  description = "S3 URI of the admin API token read by the runner module."
  value       = "s3://${aws_s3_bucket.stand.id}/${aws_s3_object.admin_token.key}"
}
