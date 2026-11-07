locals {
  prefix = var.prefix != "" ? var.prefix : terraform.workspace
  # Minted by the server module and uploaded to S3 (see admin-token.tf). The
  # semaphoreui provider is configured even when none of its resources are left
  # in state and refuses an empty token, so with skip_server (servers and their
  # bucket already gone) fall back to a placeholder: `terraform destroy` can then
  # plan, and down_runners.sh --skip-server drops the server-side runner records
  # from state instead of asking a dead API to delete them.
  s3_bucket          = var.s3_bucket != "" ? var.s3_bucket : "${local.prefix}-semaphore-stand"
  admin_token_s3_key = "${local.prefix}/admin.token"
  api_token          = sensitive(var.skip_server ? "missing-admin-token" : trimspace(data.aws_s3_object.admin_token[0].body))
  web_root           = var.web_root != "" ? var.web_root : "https://${local.prefix}-lb.${var.parent_domain}"
  api_base_url       = "${local.web_root}/api"
  config             = yamldecode(file("${path.module}/../../../workspaces/${local.prefix}/config.yml"))
  no_server          = var.web_root != ""

  # Per-stand overrides from config.yml; the defaults keep existing stands as they are.
  semaphore_version    = tostring(lookup(local.config, "semaphore_version", var.semaphore_version))
  runner_size          = lookup(local.config, "runner_size", var.size)
  runner_executor_type = lookup(local.config, "runner_executor_type", var.runner_executor_type)
  # runner.check_interval_seconds of every runner (Semaphore >= 2.19.16): how
  # often it asks the server for new jobs. 0 leaves it out of the runner config
  # (runner default, 1s). The 1s progress report/heartbeat is not affected.
  runner_check_interval_seconds = lookup(local.config, "runner_check_interval_seconds", 0)

  # runner_count generates <runner_name_prefix>01..NN on top of the explicit
  # `runners:` entries (an explicit entry with the same key wins), so a load
  # test is scaled by one number instead of a long list.
  runner_count       = lookup(local.config, "runner_count", 0)
  runner_name_prefix = lookup(local.config, "runner_name_prefix", "r")
  generated_runners = {
    for i in range(local.runner_count) : format("%s%02d", local.runner_name_prefix, i + 1) => {
      name = format("%s%02d", local.runner_name_prefix, i + 1)
    }
  }

  # One runner record + droplet per entry, normalized to the same shape.
  # try(): `runners:` may be missing or, with every entry commented out, null.
  runners = {
    for key, r in merge(local.generated_runners, try(local.config.runners, {})) : key => {
      name                   = r.name
      runner_executor_type   = lookup(r, "runner_executor_type", local.runner_executor_type)
      check_interval_seconds = lookup(r, "check_interval_seconds", local.runner_check_interval_seconds)
    }
  }
}
