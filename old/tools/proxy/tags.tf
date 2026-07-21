# Tag must exist before the firewall references it, so it is declared as a
# first-class resource rather than an inline droplet tag string.
resource "digitalocean_tag" "base" {
  name = local.prefix
}
