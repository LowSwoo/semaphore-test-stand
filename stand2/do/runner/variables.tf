variable "do_token" {
  description = "DigitalOcean API token (or set DIGITALOCEAN_TOKEN)."
  type        = string
  sensitive   = true
}

variable "do_k8s_cluster" {
  description = "DigitalOcean Kubernetes cluster ID (or set DO_K8S_CLUSTER)."
  type        = string
  default     = ""
}

variable "runner_executor_type" {
  description = "Executor type used by the runners (e.g. \"docker\" or \"k8s\")."
  type        = string
  default     = "docker"
}

variable "size" {
  description = "Droplet size slug used for all 'small' droplets."
  type        = string
  default     = "s-2vcpu-4gb"
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
  default     = "fra1"
}

variable "prefix" {
  description = "Optional resource prefix override. If empty, terraform.workspace is used."
  type        = string
  default     = ""
}

variable "semaphore_version" {
  description = "Semaphore runner version (or set SEMAPHORE_RUNNER_VERSION)."
  type        = string
  default     = "2.18.6-beta1"
}

variable "parent_domain" {
  description = "Parent domain hosted in Cloudflare (e.g. semaphoreui.dev). The '<prefix>.<parent_domain>' sub-zone is delegated to DigitalOcean nameservers."
  type        = string
}

variable "web_root" {
  type    = string
  default = ""
}

variable "ssh_key_name" {
  description = "Name of the existing SSH key in DigitalOcean to use for runner access (or set SSH_KEY_NAME)."
  type        = string
}