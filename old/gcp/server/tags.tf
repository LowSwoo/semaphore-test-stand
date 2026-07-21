# Google Cloud has no first-class tag resource — network tags are plain strings
# attached to instances and matched by firewall `target_tags`. They are centralised
# here as locals so instances and firewalls stay in sync.
locals {
  tag_base     = var.prefix
  tag_ui       = "${var.prefix}-ui"
  tag_database = "${var.prefix}-database"
  tag_redis    = "${var.prefix}-redis"
}
