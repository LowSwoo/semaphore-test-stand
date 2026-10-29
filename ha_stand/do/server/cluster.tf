# Semaphore UI droplets behind the load balancer (modules/do/semaphore).
# DigitalOcean has no availability zones, so they share one region/VPC.
module "semaphore" {
  source = "../../../modules/do/semaphore"

  node_count = local.config.cluster
  image      = var.image
  size       = "s-4vcpu-8gb"
  region     = var.region
  vpc_uuid   = digitalocean_vpc.main.id
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  tags       = [digitalocean_tag.base.id, digitalocean_tag.ui.id]

  db = {
    host     = module.postgres.private_ip
    name     = var.db_name
    user     = var.db_user
    password = var.db_password
  }
  redis = {
    sentinel_addrs    = module.redis.sentinel_addrs
    master_name       = local.redis_master_name
    sentinel_password = var.redis_sentinel_password
    password          = var.redis_password
    ha_enabled        = !local.config.ha_disabled
  }

  web_root              = local.web_root
  cookie_hash           = var.semaphore_cookie_hash
  cookie_encryption     = var.semaphore_cookie_encryption
  access_key_encryption = var.semaphore_access_key_encryption
  admin_user            = var.semaphore_admin_user
  admin_password        = var.semaphore_admin_password
  admin_email           = var.semaphore_admin_email
  semaphore_version     = var.semaphore_version
  subscription_key      = local.config.subscription_key
}
