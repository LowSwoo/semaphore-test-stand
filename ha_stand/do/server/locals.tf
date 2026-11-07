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

  # How the UI nodes reach Redis in HA mode: "redis_sentinel" (Semaphore >=
  # 2.20.16-beta5) or "redis" — straight to redis-1, the only form 2.19.x knows.
  ha_engine = lookup(local.config, "ha_engine", "redis_sentinel")

  # Per-stand Semaphore release; falls back to TF_VAR_semaphore_version (.env).
  semaphore_version = tostring(lookup(local.config, "semaphore_version", var.semaphore_version))
}
