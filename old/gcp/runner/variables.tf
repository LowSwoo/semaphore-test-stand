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
  description = "Compute Engine machine type used for all runner instances."
  type        = string
  default     = "e2-small"
}

variable "image" {
  description = "Boot disk image for all instances."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "region" {
  description = "Default region for the google provider. Per-runner placement is set in var.runners; this only seeds provider-level defaults."
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "Default zone for the google provider. Per-runner placement is set in var.runners; this only seeds provider-level defaults."
  type        = string
  default     = "a"
}

variable "runner_cidr" {
  description = "Base CIDR for the runner VPC. A non-overlapping /24 is carved from it per region (so this should be at most a /16 to leave room)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "web_root" {
  description = "Semaphore web root / API base host (e.g. https://lb.stand2.semaphoreui.dev)."
  type        = string
  default     = "https://localhost:3000"
}

variable "semaphore_version" {
  description = "Semaphore runner version (or set SEMAPHORE_RUNNER_VERSION)."
  type        = string
  default     = "2.18.6-beta5"
}