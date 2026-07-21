resource "digitalocean_ssh_key" "default" {
  name       = "${local.prefix}-key"
  public_key = local.ssh_public_key
}

# Single nginx droplet. cloud-init installs nginx, generates a self-signed
# origin certificate and writes the reverse-proxy config that terminates TLS on
# :443 and forwards to the upstream service on :3000.
resource "digitalocean_droplet" "proxy" {
  name   = local.prefix
  image  = var.image
  size   = var.size
  region = var.region

  ssh_keys = [data.digitalocean_ssh_key.default.id]
  tags     = [digitalocean_tag.base.id]

  user_data = templatefile("${path.module}/cloud-init/nginx.yaml.tftpl", {
    server_name   = local.fqdn
  })
}
