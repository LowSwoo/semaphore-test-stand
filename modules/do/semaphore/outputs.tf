output "nodes" {
  description = "Droplets by name."
  value = {
    for d in digitalocean_droplet.node : d.name => {
      region     = d.region
      public_ip  = d.ipv4_address
      private_ip = d.ipv4_address_private
    }
  }
}

output "urns" {
  description = "Droplet URNs, for digitalocean_project_resources."
  value       = digitalocean_droplet.node[*].urn
}

output "bootstrap_node" {
  description = "The node that created the admin user; the admin token is minted on it."
  value = {
    id        = digitalocean_droplet.node[0].id
    public_ip = digitalocean_droplet.node[0].ipv4_address
  }
}
