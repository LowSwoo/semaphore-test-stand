variable "nodes" {
  description = "Redis droplets: 1 master + (nodes - 1) replicas, Sentinel on each."
  type        = number

  validation {
    condition     = var.nodes >= 1
    error_message = "nodes must be at least 1."
  }
}

variable "sentinel_quorum" {
  description = "Sentinels that must agree the master is down."
  type        = number
}

variable "master_name" {
  description = "Master name in `sentinel monitor` and in Semaphore's ha.redis_sentinel.master_name."
  type        = string
}

variable "redis_password" {
  description = "Password of the Redis data nodes (requirepass / masterauth)."
  type        = string
  sensitive   = true
}

variable "sentinel_password" {
  description = "Password of the Sentinel processes (requirepass in sentinel.conf)."
  type        = string
  sensitive   = true
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
  description = "DigitalOcean SSH key IDs for root access."
  type        = list(string)
}

variable "tags" {
  description = "Tag IDs; firewalls attach through them."
  type        = list(string)
}
