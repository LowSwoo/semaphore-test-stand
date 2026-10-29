# PostgreSQL droplet shared by the Semaphore nodes, listening on the VPC
# address only (templates/postgres.yaml.tftpl).
locals {
  # DigitalOcean metadata endpoint for the droplet's own private IP, injected
  # into the cloud-init template (another cloud would pass its own lookup).
  metadata_private_ip_cmd = "curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address"
}

resource "digitalocean_droplet" "postgres" {
  name     = var.name
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = var.vpc_uuid

  ssh_keys = var.ssh_keys
  tags     = var.tags

  user_data = templatefile("${path.module}/templates/postgres.yaml.tftpl", {
    db_name        = var.db_name
    db_user        = var.db_user
    db_password    = var.db_password
    vpc_ip_range   = var.vpc_ip_range
    private_ip_cmd = local.metadata_private_ip_cmd
  })
}
