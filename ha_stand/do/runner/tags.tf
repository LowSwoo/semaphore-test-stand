# Tags must exist before firewalls / load balancers reference them, so they
# are declared as first-class resources rather than inline droplet tag strings.


resource "digitalocean_tag" "runner" {
  name = "${local.prefix}-runner"
}
