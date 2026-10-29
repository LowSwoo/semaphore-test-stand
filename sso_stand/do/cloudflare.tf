# Public hostname of the Semaphore node, served through the Cloudflare proxy:
# TLS terminates at the edge, the origin is plain HTTP :80. Flat
# '<prefix>-ui.<parent_domain>' because the universal certificate covers only
# first-level subdomains. Dex gets '<prefix>-dex' from modules/do/idp.
data "cloudflare_zone" "parent" {
  name = var.parent_domain
}

resource "cloudflare_record" "ui" {
  zone_id = data.cloudflare_zone.parent.id
  name    = "${local.prefix}-ui"
  type    = "A"
  content = module.semaphore.bootstrap_node.public_ip
  proxied = true
  ttl     = 1 # Cloudflare requires TTL 'automatic' (1) for proxied records.
}
