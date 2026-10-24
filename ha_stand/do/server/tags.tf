# Tags must exist before firewalls / load balancers reference them, so they
# are declared as first-class resources rather than inline droplet tag strings.
resource "digitalocean_tag" "base" {
  name = local.prefix
}

resource "digitalocean_tag" "ui" {
  name = "${local.prefix}-ui"
}

resource "digitalocean_tag" "database" {
  name = "${local.prefix}-database"
}

resource "digitalocean_tag" "redis" {
  name = "${local.prefix}-redis"
}
