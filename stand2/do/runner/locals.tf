locals {
  prefix               = terraform.workspace
  api_token            = sensitive(trimspace(file("${path.module}/../../../workspaces/${local.prefix}/admin.token")))
  dns_zone             = "${local.prefix}.${var.parent_domain}"
  web_root             = var.web_root != "" ? var.web_root : "https://lb.${local.dns_zone}"
  api_base_url         = "${local.web_root}/api"
  config               = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))
  no_server            = var.web_root != ""
  runner_executor_type = var.runner_executor_type
}
