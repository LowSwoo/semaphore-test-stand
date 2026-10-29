locals {
  prefix         = var.prefix != "" ? var.prefix : terraform.workspace
  api_token_path = "/tmp/${local.prefix}-admin.token"
  # S3 location the runner module reads the admin token from.
  s3_bucket          = var.s3_bucket != "" ? var.s3_bucket : "${local.prefix}-semaphore-stand"
  admin_token_s3_key = "${local.prefix}/admin.token"
  lb_hostname        = "${local.prefix}-lb.${var.parent_domain}"
  web_root           = "https://${local.lb_hostname}"
  api_base_url       = "${local.web_root}/api"
  config             = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))

  # Redis Sentinel cluster shape. Optional in config.yml so existing stands keep working.
  redis_nodes           = lookup(local.config, "redis_nodes", 2)
  redis_sentinel_quorum = lookup(local.config, "redis_sentinel_quorum", 1)
  redis_master_name     = lookup(local.config, "redis_master_name", "semaphore")
}
