# Semaphore UI nodes sharing one PostgreSQL database (templates/semaphore-systemd.yaml.tftpl).
# With `redis` set they form an HA cluster coordinated through Redis Sentinel;
# without it the ha: block is left out, which only makes sense for node_count = 1.
resource "digitalocean_droplet" "node" {
  count    = var.node_count
  name     = "${var.name_prefix}-${count.index + 1}"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = var.vpc_uuid

  ssh_keys = var.ssh_keys
  tags     = var.tags

  user_data = templatefile("${path.module}/templates/semaphore-systemd.yaml.tftpl", {
    # Only the first node bootstraps the admin user + API token, so they are
    # created exactly once across the cluster (the shared DB is migrated under
    # an advisory lock separately).
    bootstrap               = count.index == 0
    db_host                 = var.db.host
    db_name                 = var.db.name
    db_user                 = var.db.user
    db_password             = var.db.password
    redis_enabled           = var.redis != null
    redis_sentinel_addrs    = try(var.redis.sentinel_addrs, [])
    redis_master_name       = try(var.redis.master_name, "")
    redis_sentinel_password = try(var.redis.sentinel_password, "")
    redis_password          = try(var.redis.password, "")
    ha_enabled              = try(var.redis.ha_enabled, false) ? "true" : "false"
    port                    = var.port
    web_root                = var.web_root
    cookie_hash             = var.cookie_hash
    cookie_encryption       = var.cookie_encryption
    access_key_encryption   = var.access_key_encryption
    admin_user              = var.admin_user
    admin_password          = var.admin_password
    admin_email             = var.admin_email
    semaphore_version       = var.semaphore_version
    node_index              = count.index + 1
    subscription_key        = var.subscription_key
    use_remote_runner       = var.use_remote_runner
    extra_config            = length(var.extra_config) > 0 ? trimspace(yamlencode(var.extra_config)) : ""
  })

  depends_on = [digitalocean_droplet.node[0]]
}
