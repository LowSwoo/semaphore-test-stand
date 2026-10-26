locals {
  prefix = var.prefix != "" ? var.prefix : terraform.workspace
  # Minted by the server module and uploaded to S3 (see admin-token.tf). The
  # semaphoreui provider is configured even when none of its resources are left
  # in state and refuses an empty token, so with skip_server (servers and their
  # bucket already gone) fall back to a placeholder: `terraform destroy` can then
  # plan, and down_runners.sh --skip-server drops the server-side runner records
  # from state instead of asking a dead API to delete them.
  s3_bucket            = var.s3_bucket != "" ? var.s3_bucket : "${local.prefix}-semaphore-stand"
  admin_token_s3_key   = "${local.prefix}/admin.token"
  api_token            = sensitive(var.skip_server ? "missing-admin-token" : trimspace(data.aws_s3_object.admin_token[0].body))
  web_root             = var.web_root != "" ? var.web_root : "https://${local.prefix}-lb.${var.parent_domain}"
  api_base_url         = "${local.web_root}/api"
  config               = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))
  no_server            = var.web_root != ""
  runner_executor_type = var.runner_executor_type
}
