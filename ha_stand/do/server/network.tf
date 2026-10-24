
data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "digitalocean_vpc" "main" {
  name     = "${local.prefix}-cluster-vpc"
  region   = var.region
  ip_range = local.config.cluster_ip_range
}
