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
variable "skip_server" {
  description = <<-EOT
    Destroy-time switch used by down_runners.sh --skip-server: the Semaphore
    server (and the DigitalOcean project it created) may already be gone, so
    nothing may be looked up or deleted there. Disables the project data source;
    the semaphoreui_runner.* records are dropped from state by the script.
  EOT
  type        = bool
  default     = false
}

# --- S3 / Cloudflare R2 (admin token exchange between server and runner modules)

variable "s3_endpoint" {
  description = "S3 API endpoint of the bucket holding the stand's admin token. Cloudflare R2: https://<account_id>.r2.cloudflarestorage.com. Empty: AWS S3."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Region of the S3 bucket holding the stand's admin token. Cloudflare R2: \"auto\"."
  type        = string
  default     = "auto"
}

variable "aws_access_key" {
  description = "S3 access key ID (R2 API token access key / AWS access key). Leave empty to use the default AWS credential chain (env vars, profile, instance role)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "S3 secret access key (R2 API token secret / AWS secret key). Leave empty to use the default AWS credential chain."
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_bucket" {
  description = "Name of the S3 bucket that carries the admin token from the server module to the runner module. Empty: '<prefix>-semaphore-stand'."
  type        = string
  default     = ""
}
