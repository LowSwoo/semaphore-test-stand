# DigitalOcean Cloud Firewalls filter both public and private (VPC) traffic,
# so internal Postgres/Redis access is opened explicitly to the VPC range.
resource "digitalocean_firewall" "main" {
  name = "${local.prefix}-fw"
  tags = [digitalocean_tag.base.id]

  # --- Inbound ---
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Semaphore UI (load balancer + direct access).
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # PostgreSQL — VPC only.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "5432"
    source_addresses = [local.config.cluster_ip_range]
  }

  # Redis — VPC only.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6379"
    source_addresses = [local.config.cluster_ip_range]
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
