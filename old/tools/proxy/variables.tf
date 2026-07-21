variable "do_token" {
  description = "DigitalOcean API token (or set DIGITALOCEAN_TOKEN)."
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit + zone read on the parent domain (or set CLOUDFLARE_API_TOKEN)."
  type        = string
  sensitive   = true
}

variable "parent_domain" {
  description = "Parent domain hosted in Cloudflare (e.g. semaphoreui.dev). The proxy record is created directly in this (proxied) zone."
  type        = string
}

variable "size" {
  description = "Droplet size slug for the proxy."
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "image" {
  description = "OS image slug for the proxy droplet."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "region" {
  description = "DigitalOcean region for the proxy droplet."
  type        = string
  default     = "fra1"
}
