# DigitalOcean Cloud Firewalls filter both public and private (VPC) traffic.
# base: every droplet (SSH, ICMP, egress, Postgres from the VPC). The idp
# droplet gets its own ports from modules/do/idp.
resource "digitalocean_firewall" "main" {
  name = "${local.prefix}-fw"
  tags = [digitalocean_tag.base.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # PostgreSQL — VPC only.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "5432"
    source_addresses = [local.config.cluster_ip_range]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

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

# Semaphore listens on :80 and is only reached through the Cloudflare proxy.
data "cloudflare_ip_ranges" "edge" {}

resource "digitalocean_firewall" "ui" {
  name = "${local.prefix}-ui-fw"
  tags = [digitalocean_tag.ui.id]

  inbound_rule {
    protocol   = "tcp"
    port_range = "80"
    source_addresses = concat(
      data.cloudflare_ip_ranges.edge.ipv4_cidr_blocks,
      data.cloudflare_ip_ranges.edge.ipv6_cidr_blocks,
    )
  }
}
