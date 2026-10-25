locals {
  prefix = var.prefix != "" ? var.prefix : terraform.workspace
  # Minted by the server module. May be gone when the servers were destroyed first
  # (or the stand died). The semaphoreui provider is configured even when none of
  # its resources are left in state and refuses an empty token, so fall back to a
  # placeholder: `terraform destroy` can then plan, and down_runners.sh
  # --skip-server drops the server-side runner records from state instead of
  # asking a dead API to delete them.
  api_token_path       = "/tmp/${local.prefix}-admin.token"
  api_token            = sensitive(fileexists(local.api_token_path) ? trimspace(file(local.api_token_path)) : "missing-admin-token")
  web_root             = var.web_root != "" ? var.web_root : "https://${local.prefix}-lb.${var.parent_domain}"
  api_base_url         = "${local.web_root}/api"
  config               = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))
  no_server            = var.web_root != ""
  runner_executor_type = var.runner_executor_type
}
