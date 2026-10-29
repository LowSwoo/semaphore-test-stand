variable "name" {
  description = "Droplet name."
  type        = string
  default     = "postgres"
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
  description = "VPC the droplet is attached to."
  type        = string
}

variable "vpc_ip_range" {
  description = "CIDR of the VPC; pg_hba.conf admits the Semaphore role from it."
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

variable "db_name" {
  description = "Database created for Semaphore."
  type        = string
}

variable "db_user" {
  description = "Role that owns the database."
  type        = string
}

variable "db_password" {
  description = "Password of db_user."
  type        = string
  sensitive   = true
}
