# Network tag attached to every runner instance and matched by the runner
# firewall's target_tags.
locals {
  tag_runner = "${var.prefix}-runner"
}
