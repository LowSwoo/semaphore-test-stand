variable "api_base_url" {
  description = "Semaphore API base URL (or set SEMAPHOREUI_API_BASE_URL)."
  type        = string
  default     = "https://localhost:3000/api"
}

variable "tls_skip_verify" {
  description = "Skip TLS verification for the API (local HTTPS with a self-signed cert)."
  type        = bool
  default     = true
}

variable "api_token" {
  description = "Semaphore API token (or set SEMAPHOREUI_API_TOKEN)."
  type        = string
  sensitive   = true
}
