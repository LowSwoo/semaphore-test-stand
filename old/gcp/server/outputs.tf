output "project_id" {
  description = "Google Cloud project hosting all resources."
  value       = data.google_project.main.project_id
}

output "semaphore_url" {
  description = "HTTPS entry point for the Semaphore UI."
  value       = "https://${local.lb_fqdn}"
}

output "delegated_zone" {
  description = "Sub-zone delegated to Google Cloud DNS via NS records in the parent domain."
  value       = local.dns_zone
}

output "delegated_zone_nameservers" {
  description = "Google Cloud DNS nameservers the sub-zone is delegated to."
  value       = google_dns_managed_zone.main.name_servers
}

output "load_balancer_ip" {
  description = "Public IP of the load balancer (HTTPS :443, HTTP :80 redirects)."
  value       = google_compute_global_address.lb.address
}

# Instances have no external IP (org policy); only private IPs are surfaced.
output "cluster_servers" {
  description = "Semaphore UI cluster instances."
  value = {
    for i in google_compute_instance.cluster : i.name => {
      zone       = i.zone
      private_ip = i.network_interface[0].network_ip
    }
  }
}

output "postgres_server" {
  description = "PostgreSQL instance."
  value = {
    private_ip = google_compute_instance.postgres.network_interface[0].network_ip
  }
}

output "redis_server" {
  description = "Redis instance."
  value = {
    private_ip = google_compute_instance.redis.network_interface[0].network_ip
  }
}
