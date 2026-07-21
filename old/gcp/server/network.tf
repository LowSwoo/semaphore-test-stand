# Private VPC + subnet. Unlike DigitalOcean there is no SSH-key resource — the
# public key is injected per-instance via the `ssh-keys` metadata entry.
resource "google_compute_network" "main" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.prefix}-subnet"
  ip_cidr_range = var.subnet_ip_range
  region        = var.region
  network       = google_compute_network.main.id
}
