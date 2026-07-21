# Public hostname for the load balancer, served through the Cloudflare proxy:
# TLS terminates at the Cloudflare edge with the zone's universal certificate
# and responses are cached/accelerated by Cloudflare.
#
# Cloudflare's universal certificate only covers first-level subdomains of the
# zone, so the hostname is flat ('<prefix>-lb.<parent_domain>') instead of a
# nested 'lb.<prefix>.<parent_domain>'.

data "cloudflare_zone" "parent" {
  name = var.parent_domain
}

resource "cloudflare_record" "lb" {
  zone_id = data.cloudflare_zone.parent.id
  name    = "${local.prefix}-lb"
  type    = "A"
  content = digitalocean_loadbalancer.main.ip
  proxied = true
  ttl     = 1 # Cloudflare requires TTL 'automatic' (1) for proxied records.
}

# The load balancer serves plain HTTP, so pin SSL mode 'flexible' for this
# hostname (edge terminates TLS, origin is reached over HTTP:80) regardless of
# the zone-wide SSL setting. Note: the Cloudflare free plan allows only 3 page
# rules per zone, one is consumed per workspace.
# resource "cloudflare_page_rule" "lb_ssl" {
#   zone_id = data.cloudflare_zone.parent.id
#   target  = "${local.lb_hostname}/*"

#   actions {
#     ssl = "flexible"
#   }
# }
