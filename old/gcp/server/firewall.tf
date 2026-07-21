# Google Cloud firewall rules are scoped to network tags. Egress is allowed by
# default, so only ingress is declared. Postgres/Redis are opened to the subnet
# range only; the external HTTPS load balancer reaches the UI nodes on :3000.
resource "google_compute_firewall" "ssh" {
  name          = "${var.prefix}-allow-ssh"
  network       = google_compute_network.main.id
  target_tags   = [local.tag_base]
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Semaphore UI — load balancer (Google front ends) + direct access.
resource "google_compute_firewall" "ui" {
  name          = "${var.prefix}-allow-ui"
  network       = google_compute_network.main.id
  target_tags   = [local.tag_ui]
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }
}

# PostgreSQL — subnet only.
resource "google_compute_firewall" "postgres" {
  name          = "${var.prefix}-allow-postgres"
  network       = google_compute_network.main.id
  target_tags   = [local.tag_database]
  source_ranges = [var.subnet_ip_range]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

# Redis — subnet only.
resource "google_compute_firewall" "redis" {
  name          = "${var.prefix}-allow-redis"
  network       = google_compute_network.main.id
  target_tags   = [local.tag_redis]
  source_ranges = [var.subnet_ip_range]

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }
}

resource "google_compute_firewall" "icmp" {
  name          = "${var.prefix}-allow-icmp"
  network       = google_compute_network.main.id
  target_tags   = [local.tag_base]
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }
}
