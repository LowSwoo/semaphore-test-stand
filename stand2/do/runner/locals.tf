locals {
  prefix               = var.prefix != "" ? var.prefix : terraform.workspace
  api_token            = sensitive(trimspace(file("${path.module}/../../../workspaces/${local.prefix}/admin.token")))
  web_root             = var.web_root != "" ? var.web_root : "https://${local.prefix}-lb.${var.parent_domain}"
  api_base_url         = "${local.web_root}/api"
  config               = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))
  no_server            = var.web_root != ""
  runner_executor_type = var.runner_executor_type
}
