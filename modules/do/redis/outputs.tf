output "urns" {
  description = "Droplet URNs, for digitalocean_project_resources."
  value       = concat([digitalocean_droplet.master.urn], digitalocean_droplet.replica[*].urn)
}

output "servers" {
  description = "Droplets by name (redis-1 boots as master, the rest as replicas)."
  value = {
    for d in concat([digitalocean_droplet.master], digitalocean_droplet.replica) : d.name => {
      region     = d.region
      public_ip  = d.ipv4_address
      private_ip = d.ipv4_address_private
    }
  }
}

output "sentinel_addrs" {
  description = "Sentinel endpoints (host:port), master first."
  value       = local.sentinel_addrs
}
