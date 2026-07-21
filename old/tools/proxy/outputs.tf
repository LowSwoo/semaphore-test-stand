output "project_id" {
  description = "DigitalOcean project grouping the proxy droplet."
  value       = digitalocean_project.main.id
}

output "proxy_ip" {
  description = "Public IPv4 of the nginx proxy droplet (origin behind Cloudflare)."
  value       = digitalocean_droplet.proxy.ipv4_address
}

output "proxy_url" {
  description = "Public HTTPS entry point (served through Cloudflare)."
  value       = "https://${local.fqdn}"
}