variable "node_count" {
  description = "Number of Semaphore UI nodes. More than one needs `redis`."
  type        = number
  default     = 1
}

variable "name_prefix" {
  description = "Droplet names are <name_prefix>-<n>."
  type        = string
  default     = "ui"
}

variable "image" {
  description = "OS image slug."
  type        = string
}

variable "size" {
  description = "Droplet size slug."
  type        = string
}

variable "region" {
  description = "DigitalOcean region."
  type        = string
}

variable "vpc_uuid" {
  description = "VPC the droplets are attached to."
  type        = string
}

variable "ssh_keys" {
  description = "DigitalOcean SSH key IDs for root access (the admin token is minted over SSH)."
  type        = list(string)
}

variable "tags" {
  description = "Tag IDs; firewalls and load balancers attach through them."
  type        = list(string)
}

variable "db" {
  description = "PostgreSQL connection (host is a private IP, port 5432)."
  type = object({
    host     = string
    name     = string
    user     = string
    password = string
  })
}

variable "redis" {
  description = <<-EOT
    Redis for HA mode; null leaves the ha: block out of config.yml. ha_enabled = false keeps the block but turns HA off.
    engine selects how the nodes find Redis: "redis_sentinel" (default) asks the Sentinels for the master
    (Semaphore >= 2.20.16-beta5), "redis" connects to the single address `addr` — the only form
    Semaphore 2.19.x and older understand (they ignore ha.engine and read ha.redis).
  EOT
  type = object({
    sentinel_addrs    = list(string)
    master_name       = string
    sentinel_password = string
    password          = string
    ha_enabled        = bool
    engine            = optional(string, "redis_sentinel")
    addr              = optional(string, "")
  })
  default = null

  validation {
    condition     = try(contains(["redis", "redis_sentinel"], var.redis.engine), true)
    error_message = "redis.engine must be \"redis\" or \"redis_sentinel\"."
  }

  validation {
    condition     = try(var.redis.engine != "redis" || var.redis.addr != "", true)
    error_message = "redis.addr (host:port) is required when redis.engine is \"redis\"."
  }
}

variable "port" {
  description = "Port Semaphore listens on. Below 1024 the service gets CAP_NET_BIND_SERVICE."
  type        = number
  default     = 3000
}

variable "web_root" {
  description = "Public URL of the UI (web_host); OIDC redirect URLs are built from it."
  type        = string
}

variable "cookie_hash" {
  description = "Base64 32-byte cookie hashing key, shared across the nodes."
  type        = string
  sensitive   = true
}

variable "cookie_encryption" {
  description = "Base64 32-byte cookie encryption key, shared across the nodes."
  type        = string
  sensitive   = true
}

variable "access_key_encryption" {
  description = "Base64 32-byte access key encryption key, shared across the nodes."
  type        = string
  sensitive   = true
}

variable "admin_user" {
  description = "Admin login created by the bootstrap node."
  type        = string
}

variable "admin_password" {
  description = "Admin password."
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email; set only when the bootstrap node creates the admin in an empty database."
  type        = string
}

variable "semaphore_version" {
  description = "Release downloaded from GitHub (without the leading v)."
  type        = string
}

variable "subscription_key" {
  description = "Semaphore Pro subscription key."
  type        = string
  sensitive   = true
}

variable "use_remote_runner" {
  description = "Run tasks on remote runners only (use_remote_runner in config.yml)."
  type        = bool
  default     = true
}

variable "extra_config" {
  description = "Additional top-level keys of /etc/semaphore/config.yml (e.g. ldap_*, oidc_providers), rendered with yamlencode."
  type        = any
  default     = {}
}
