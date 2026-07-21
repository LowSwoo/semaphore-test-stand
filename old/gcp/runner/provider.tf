# Authentication is taken from the environment: run `gcloud auth application-default
# login` or set GOOGLE_APPLICATION_CREDENTIALS to a service-account key file.
provider "google" {
  project = var.gcp_project
  region  = var.region
  zone    = var.zone
}

provider "semaphoreui" {
  api_base_url    = local.api_base_url
  api_token       = local.api_token
  tls_skip_verify = false
}
