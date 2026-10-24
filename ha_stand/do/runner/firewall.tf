# DigitalOcean Cloud Firewalls filter both public and private (VPC) traffic,
# so internal Postgres/Redis access is opened explicitly to the VPC range.
resource "digitalocean_firewall" "runner" {
  name = "${local.prefix}-runner2"
  tags = [digitalocean_tag.runner.id]

  # --- Inbound ---
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # --- Outbound (allow all egress: apt, Docker Hub, DB/Redis, metadata) ---
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
