resource "digitalocean_loadbalancer" "main" {
  name     = "${local.prefix}-lb"
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  # Route the 3 Semaphore UI droplets behind the LB via their shared tag.
  droplet_tag = digitalocean_tag.ui.name

  # TLS terminates at the Cloudflare edge; the LB only speaks plain HTTP.
  forwarding_rule {
    entry_protocol  = "http"
    entry_port      = 80
    target_protocol = "http"
    target_port     = 3000
  }

  healthcheck {
    protocol                 = "http"
    port                     = 3000
    path                     = "/api/ping"
    check_interval_seconds   = 10
    response_timeout_seconds = 5
    healthy_threshold        = 3
    unhealthy_threshold      = 3
  }

  depends_on = [module.semaphore]
}
