module "postgres" {
  source = "../../../modules/do/postgres"

  image        = var.image
  size         = "s-4vcpu-8gb"
  region       = var.region
  vpc_uuid     = digitalocean_vpc.main.id
  vpc_ip_range = local.config.cluster_ip_range
  ssh_keys     = [data.digitalocean_ssh_key.default.id]
  tags         = [digitalocean_tag.base.id, digitalocean_tag.database.id]

  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
}

# Redis Sentinel cluster (modules/do/redis): redis-1 boots as master, the rest
# as its replicas, every node also runs a Sentinel.
module "redis" {
  source = "../../../modules/do/redis"

  nodes             = local.redis_nodes
  sentinel_quorum   = local.redis_sentinel_quorum
  master_name       = local.redis_master_name
  redis_password    = var.redis_password
  sentinel_password = var.redis_sentinel_password

  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [data.digitalocean_ssh_key.default.id]
  tags     = [digitalocean_tag.base.id, digitalocean_tag.redis.id]
}
