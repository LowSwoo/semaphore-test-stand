# Groups the proxy droplet in its own DigitalOcean project.
resource "digitalocean_project" "main" {
  name        = local.prefix
  description = "nginx reverse proxy"
  purpose     = "Web Application"
  environment = "Development"

  resources = [digitalocean_droplet.proxy.urn]
}
