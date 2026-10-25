variable "do_token" {
  description = "DigitalOcean API token (or set DIGITALOCEAN_TOKEN)."
  type        = string
  sensitive   = true
}

variable "size" {
  description = "Droplet size slug used for all 'small' droplets."
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "image" {
  description = "OS image slug for all droplets."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "region" {
  description = <<-EOT
    DigitalOcean region for all resources. DigitalOcean does not expose
    availability zones, and a VPC + load balancer are regional, so the whole
    cluster lives in one region.
  EOT
  type        = string
  default     = "ams3"
}

variable "prefix" {
  description = "Optional resource prefix override. If empty, terraform.workspace is used."
  type        = string
  default     = ""
}

variable "parent_domain" {
  description = "Parent domain hosted in Cloudflare (e.g. semaphoreui.dev). The LB is published as a proxied '<prefix>-lb.<parent_domain>' record in this zone."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit + zone read on the parent domain (or set CLOUDFLARE_API_TOKEN)."
  type        = string
  sensitive   = true
}

# --- Application secrets / config -------------------------------------------

variable "db_name" {
  description = "PostgreSQL database name for Semaphore."
  type        = string
  default     = "semaphore"
}

variable "db_user" {
  description = "PostgreSQL user for Semaphore."
  type        = string
  default     = "semaphore"
}

variable "db_password" {
  description = "PostgreSQL password for Semaphore."
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Password of the Redis data nodes (requirepass / masterauth on every node)."
  type        = string
  sensitive   = true
}

variable "redis_sentinel_password" {
  description = "Password of the Redis Sentinel processes themselves (requirepass in sentinel.conf). Distinct from redis_password."
  type        = string
  sensitive   = true
}

variable "semaphore_admin_user" {
  description = "Initial Semaphore admin login."
  type        = string
  default     = "admin"
}

variable "semaphore_admin_password" {
  description = "Initial Semaphore admin password."
  type        = string
  sensitive   = true
}

variable "semaphore_admin_email" {
  description = "Initial Semaphore admin email."
  type        = string
  default     = "admin@example.com"
}

variable "semaphore_cookie_hash" {
  description = "Base64 32-byte key used by Semaphore to hash cookies (shared across the cluster). Generate with: head -c32 /dev/urandom | base64"
  type        = string
  sensitive   = true
}

variable "semaphore_cookie_encryption" {
  description = "Base64 32-byte key used by Semaphore to encrypt cookies (shared across the cluster). Generate with: head -c32 /dev/urandom | base64"
  type        = string
  sensitive   = true
}

variable "semaphore_access_key_encryption" {
  description = "Base64 32-byte key used by Semaphore to encrypt access keys (shared across the cluster). Generate with: head -c32 /dev/urandom | base64"
  type        = string
  sensitive   = true
}

variable "semaphore_version" {
  description = "Semaphore runner version (or set SEMAPHORE_RUNNER_VERSION)."
  type        = string
  default     = "2.20.16-beta4"
}

variable "ssh_key_name" {
  description = "Name of the existing SSH key in DigitalOcean to use for runner access (or set SSH_KEY_NAME)."
  type        = string
}