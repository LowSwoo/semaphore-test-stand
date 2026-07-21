# The organization policy `constraints/compute.vmExternalIpAccess` forbids
# external IPs on VM instances, so instances are private-only. Cloud NAT gives
# them outbound internet (apt, GitHub releases, Docker Hub, reaching the LB).
# The NAT is regional and covers every subnet in the region, so the runner
# instances (same VPC/region, separate stack) use it too.
resource "google_compute_router" "main" {
  name    = "${var.prefix}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
