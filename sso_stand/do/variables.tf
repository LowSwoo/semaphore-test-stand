variable "do_token" {
  description = "DigitalOcean API token."
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit + zone read on parent_domain."
  type        = string
  sensitive   = true
}

variable "parent_domain" {
  description = "Parent domain hosted in Cloudflare (e.g. semaphoreui.dev). Semaphore is published as '<prefix>-ui.<parent_domain>', Dex as '<prefix>-dex.<parent_domain>'."
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the existing SSH key in DigitalOcean for root access to the droplets."
  type        = string
}

variable "prefix" {
  description = "Optional resource prefix override. If empty, terraform.workspace is used."
  type        = string
  default     = ""
}

variable "region" {
  description = "DigitalOcean region for all resources."
  type        = string
  default     = "ams3"
}

variable "image" {
  description = "OS image slug for all droplets."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "size" {
  description = "Droplet size slug of the postgres and idp droplets."
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "semaphore_size" {
  description = "Droplet size slug of the Semaphore node."
  type        = string
  default     = "s-2vcpu-4gb"
}

# --- Semaphore ---------------------------------------------------------------

variable "semaphore_version" {
  description = "Semaphore release (without the leading v). LDAP + OIDC as tested here need >= 2.20.16-beta8."
  type        = string
}

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

variable "semaphore_admin_user" {
  description = "Initial Semaphore admin login. Its email is always admin@localhost (see locals.tf)."
  type        = string
  default     = "admin"
}

variable "semaphore_admin_password" {
  description = "Initial Semaphore admin password."
  type        = string
  sensitive   = true
}

variable "semaphore_cookie_hash" {
  description = "Base64 32-byte cookie hashing key. Generate with: head -c32 /dev/urandom | base64"
  type        = string
  sensitive   = true
}

variable "semaphore_cookie_encryption" {
  description = "Base64 32-byte cookie encryption key. Generate with: head -c32 /dev/urandom | base64"
  type        = string
  sensitive   = true
}

variable "semaphore_access_key_encryption" {
  description = "Base64 32-byte access key encryption key. Generate with: head -c32 /dev/urandom | base64"
  type        = string
  sensitive   = true
}

# --- Identity providers --------------------------------------------------------
# Defaults are the public integration-tests fixture values, not real secrets:
# the tests log in with the fixture users, so they stay out of .env.example.

variable "ldap_admin_password" {
  description = "OpenLDAP admin (cn=admin,dc=bookwright,dc=test) password, also Semaphore's LDAP bind password. Fixture: profiles/feature-ldap-tls/ldap.yml."
  type        = string
  default     = "Bookwright-LDAP-Bind-42!"
  sensitive   = true
}

variable "dex_client_secret" {
  description = "Secret of the 'semaphore' OIDC client in Dex. Fixture: profiles/feature-oidc-local/dex.yaml."
  type        = string
  default     = "semaphore-test-client-secret"
  sensitive   = true
}
