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

output "master_addr" {
  description = "Data endpoint (host:port) of redis-1, the node that boots as master; for Semaphore's ha.redis.addr (engine redis, no Sentinel)."
  value       = "${digitalocean_droplet.master.ipv4_address_private}:6379"
}

output "sentinel_addrs" {
  description = "Sentinel endpoints (host:port), master first."
  value       = local.sentinel_addrs
}
