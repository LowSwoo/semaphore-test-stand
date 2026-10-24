resource "digitalocean_vpc" "main" {
  name      = "${local.prefix}-runners-vpc"
  region    = var.region
  ip_range  = local.config.runners_ip_range
}

data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}