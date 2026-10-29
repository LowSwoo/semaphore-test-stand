variable "prefix" {
  description = "Stand name; prefixes the tag, the firewall and the Dex hostname."
  type        = string
}

variable "ldap_enabled" {
  description = "Run OpenLDAP (:389, VPC only)."
  type        = bool
  default     = true
}

variable "dex_enabled" {
  description = "Run Dex (:80 behind a proxied <prefix>-dex.<parent_domain> record)."
  type        = bool
  default     = true
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
  description = "VPC shared with the Semaphore nodes."
  type        = string
}

variable "vpc_ip_range" {
  description = "CIDR allowed to reach OpenLDAP."
  type        = string
}

variable "ssh_keys" {
  description = "DigitalOcean SSH key IDs for root access."
  type        = list(string)
}

variable "tags" {
  description = "Extra tag IDs (the stand's base firewall: SSH and egress)."
  type        = list(string)
  default     = []
}

variable "parent_domain" {
  description = "Cloudflare zone the Dex record is created in."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "ID of the parent_domain zone."
  type        = string
}

variable "semaphore_web_root" {
  description = "Public URL of Semaphore; the OIDC redirect URIs point at it."
  type        = string
}

variable "ldap_admin_password" {
  description = "OpenLDAP admin (cn=admin,dc=bookwright,dc=test) password, also Semaphore's LDAP bind password."
  type        = string
  sensitive   = true
}

variable "dex_client_secret" {
  description = "Secret of the 'semaphore' OIDC client in Dex."
  type        = string
  sensitive   = true
}
