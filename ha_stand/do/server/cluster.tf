# 3 Semaphore UI droplets behind the load balancer. DigitalOcean has no
# availability zones, so they share one region/VPC. Private IPs of Postgres
# and Redis are resolved from their droplet resources (created first).
resource "digitalocean_droplet" "cluster" {
  count    = local.config.cluster
  name     = "ui-${count.index + 1}"
  image    = var.image
  size     = "s-4vcpu-8gb"
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [data.digitalocean_ssh_key.default.id]
  tags     = [digitalocean_tag.base.id, digitalocean_tag.ui.id]

  user_data = templatefile("${path.module}/../../shared/cloud-init/semaphore-systemd.yaml.tftpl", {
    # Only the first node bootstraps the admin user + API token, so they are
    # created exactly once across the cluster (the shared DB is migrated under
    # an advisory lock separately).
    bootstrap             = count.index == 0
    db_host               = digitalocean_droplet.postgres.ipv4_address_private
    db_name               = var.db_name
    db_user               = var.db_user
    db_password           = var.db_password
    redis_host            = digitalocean_droplet.redis.ipv4_address_private
    redis_password        = var.redis_password
    web_root              = local.web_root
    cookie_hash           = var.semaphore_cookie_hash
    cookie_encryption     = var.semaphore_cookie_encryption
    access_key_encryption = var.semaphore_access_key_encryption
    admin_user            = var.semaphore_admin_user
    admin_password        = var.semaphore_admin_password
    admin_email           = var.semaphore_admin_email
    semaphore_version     = var.semaphore_version
    node_index            = count.index + 1
    subscription_key      = local.config.subscription_key
    ha_enabled            = local.config.ha_disabled ? "false" : "true"
  })

  depends_on = [digitalocean_droplet.cluster[0]]
}
