# SSO stand: one Semaphore node with PostgreSQL and an idp droplet running
# OpenLDAP and Dex, built from the same modules as ha_stand (modules/do/*).
# No Redis/HA, no load balancer, no runners.

module "postgres" {
  source = "../../modules/do/postgres"

  image        = var.image
  size         = var.size
  region       = var.region
  vpc_uuid     = digitalocean_vpc.main.id
  vpc_ip_range = local.config.cluster_ip_range
  ssh_keys     = [data.digitalocean_ssh_key.default.id]
  tags         = [digitalocean_tag.base.id, digitalocean_tag.database.id]

  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
}

module "idp" {
  source = "../../modules/do/idp"

  prefix       = local.prefix
  ldap_enabled = local.ldap_enabled
  dex_enabled  = local.dex_enabled

  image        = var.image
  size         = var.size
  region       = var.region
  vpc_uuid     = digitalocean_vpc.main.id
  vpc_ip_range = local.config.cluster_ip_range
  ssh_keys     = [data.digitalocean_ssh_key.default.id]
  tags         = [digitalocean_tag.base.id]

  parent_domain       = var.parent_domain
  cloudflare_zone_id  = data.cloudflare_zone.parent.id
  semaphore_web_root  = local.web_root
  ldap_admin_password = var.ldap_admin_password
  dex_client_secret   = var.dex_client_secret
}

# Port 80 because Cloudflare proxies HTTPS :443 to plain HTTP :80 on the origin
# (zone SSL mode Flexible); there is no load balancer to translate to :3000.
module "semaphore" {
  source = "../../modules/do/semaphore"

  node_count = 1
  image      = var.image
  size       = var.semaphore_size
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

  port                  = 80
  use_remote_runner     = false
  web_root              = local.web_root
  cookie_hash           = var.semaphore_cookie_hash
  cookie_encryption     = var.semaphore_cookie_encryption
  access_key_encryption = var.semaphore_access_key_encryption
  admin_user            = var.semaphore_admin_user
  admin_password        = var.semaphore_admin_password
  admin_email           = local.admin_email
  semaphore_version     = var.semaphore_version
  subscription_key      = local.config.subscription_key
  extra_config          = module.idp.semaphore_config
}
