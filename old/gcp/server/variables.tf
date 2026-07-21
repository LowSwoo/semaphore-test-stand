variable "gcp_project" {
  description = "Google Cloud project ID that hosts all resources."
  type        = string
}

variable "prefix" {
  description = "Name prefix applied to every resource."
  type        = string
  default     = "semaphore"
}

variable "ssh_user" {
  description = "Linux user the SSH public key is registered for (instance metadata `ssh-keys`)."
  type        = string
  default     = "ubuntu"
}

variable "machine_type" {
  description = "Compute Engine machine type used for all 'small' instances."
  type        = string
  default     = "e2-small"
}

variable "image" {
  description = "Boot disk image for all instances."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "region" {
  description = <<-EOT
    Google Cloud region for regional resources (subnet, the external HTTPS load
    balancer is global). The whole cluster lives in one region.
  EOT
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "Compute Engine zone for all instances (must be inside var.region)."
  type        = string
  default     = "europe-west3-a"
}

variable "parent_domain" {
  description = "Parent domain hosted in Cloudflare (e.g. semaphoreui.dev). The '<prefix>.<parent_domain>' sub-zone is delegated to Google Cloud DNS nameservers."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit + zone read on the parent domain (or set CLOUDFLARE_API_TOKEN)."
  type        = string
  sensitive   = true
}

variable "lb_subdomain" {
  description = "Label for the load balancer hostname within the delegated zone, i.e. <lb_subdomain>.<prefix>.<parent_domain>."
  type        = string
  default     = "lb"
}

variable "subnet_ip_range" {
  description = "Private subnet CIDR. Postgres/Redis allow connections from this range."
  type        = string
  default     = "10.10.10.0/24"
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
  description = "Redis password."
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
  default     = "2.18.6-beta1"
}