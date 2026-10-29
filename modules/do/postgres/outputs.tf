output "urn" {
  description = "Droplet URN, for digitalocean_project_resources."
  value       = digitalocean_droplet.postgres.urn
}

output "public_ip" {
  value = digitalocean_droplet.postgres.ipv4_address
}

output "private_ip" {
  description = "VPC address the Semaphore nodes connect to (port 5432)."
  value       = digitalocean_droplet.postgres.ipv4_address_private
}
