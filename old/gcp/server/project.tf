# Unlike DigitalOcean, the Google Cloud project is a pre-existing container
# (var.gcp_project) rather than a Terraform-created grouping resource. It is
# read here only to surface its ID in the outputs.
data "google_project" "main" {
  project_id = var.gcp_project
}
