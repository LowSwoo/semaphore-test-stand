# Runners need no inbound service ports. Admin access is over IAP TCP forwarding
# (instances have no external IP), so SSH is allowed only from the IAP range.
# Egress is allowed by default, which covers apt, the release download, and
# reaching the Semaphore server through its public load balancer.
resource "google_compute_firewall" "runner_ssh" {
  name          = "${var.prefix}-runner-allow-ssh"
  network       = google_compute_network.runners.id
  target_tags   = [local.tag_runner]
  source_ranges = ["35.235.240.0/20"] # Identity-Aware Proxy TCP forwarding range.

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Allow ICMP within the runner VPC for diagnostics (the instances are otherwise
# unreachable from the internet).
resource "google_compute_firewall" "runner_icmp" {
  name          = "${var.prefix}-runner-allow-icmp"
  network       = google_compute_network.runners.id
  target_tags   = [local.tag_runner]
  source_ranges = [var.runner_cidr]

  allow {
    protocol = "icmp"
  }
}
