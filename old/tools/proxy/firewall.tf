# DigitalOcean Cloud Firewall for the nginx proxy droplet: SSH for management
# and HTTPS for the proxied traffic. Cloudflare proxies the public endpoint, so
# :443 is reached from Cloudflare's edge (left open here for simplicity; lock it
# down to Cloudflare's published IP ranges if you want origin-pull only).
resource "digitalocean_firewall" "main" {
  name = "${local.prefix}-fw"
  tags = [digitalocean_tag.base.id]

  # --- Inbound ---
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # --- Outbound (allow all egress: apt, the :3000 upstream, metadata) ---
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
