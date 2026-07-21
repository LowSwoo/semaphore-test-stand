locals {
  api_base_url = "${var.web_root}/api"
  api_token = sensitive(trimspace(file("${path.module}/../../../keys/stand2_${var.prefix}.token")))
  ssh_public_key = file("${path.module}/../../../keys/stand2_${var.prefix}.pub")
}
