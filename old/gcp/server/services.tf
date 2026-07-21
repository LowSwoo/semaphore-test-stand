# Enable the Google Cloud APIs this stack relies on. Other resources depend on
# these (via depends_on) so a cold `terraform apply` enables the APIs first.
resource "google_project_service" "compute" {
  project = var.gcp_project
  service = "compute.googleapis.com"

  # Keep the API enabled if the stack is destroyed (other resources may use it).
  disable_on_destroy = false
}

resource "google_project_service" "dns" {
  project = var.gcp_project
  service = "dns.googleapis.com"

  disable_on_destroy = false
}
