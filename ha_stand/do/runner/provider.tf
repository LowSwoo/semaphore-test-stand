provider "digitalocean" {
  token = var.do_token
}

provider "semaphoreui" {
  api_base_url    = local.api_base_url
  api_token       = local.api_token
  tls_skip_verify = false
}
