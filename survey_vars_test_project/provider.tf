provider "semaphoreui" {
  api_base_url    = var.api_base_url
  api_token       = var.api_token
  tls_skip_verify = var.tls_skip_verify
}

provider "restapi" {
  uri                  = trimsuffix(var.api_base_url, "/")
  insecure             = var.tls_skip_verify
  write_returns_object = true
  id_attribute         = "id"

  headers = {
    Authorization = "Bearer ${var.api_token}"
    Content-Type  = "application/json"
  }
}
