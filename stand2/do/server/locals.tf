locals {
  prefix         = terraform.workspace
  api_token_path = "${path.module}/../../../workspaces/${local.prefix}/admin.token"
  lb_hostname    = "${local.prefix}-lb.${var.parent_domain}"
  web_root       = "https://${local.lb_hostname}"
  api_base_url   = "${local.web_root}/api"
  config         = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))
}
