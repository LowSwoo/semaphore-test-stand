locals {
  prefix         = "proxy-${terraform.workspace}"
  ssh_public_key = file("${path.module}/../../keys/${local.prefix}/id_rsa.pub")
  record_name = local.prefix
  fqdn        = "${local.record_name}.${var.parent_domain}"
}
