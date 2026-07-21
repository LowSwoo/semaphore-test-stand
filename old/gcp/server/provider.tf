# Authentication is taken from the environment: run `gcloud auth application-default
# login` or set GOOGLE_APPLICATION_CREDENTIALS to a service-account key file.
provider "google" {
  project = var.gcp_project
  region  = var.region
  zone    = var.zone
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
