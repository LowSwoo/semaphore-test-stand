locals {
  # DigitalOcean metadata endpoint for the droplet's own private IP. Injected
  # into the shared postgres/redis cloud-init templates (GCP uses a different one).
  metadata_private_ip_cmd = "curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address"
}

resource "digitalocean_droplet" "postgres" {
  name     = "postgres"
  image    = var.image
  size     = "s-4vcpu-8gb"
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [data.digitalocean_ssh_key.default.id]
  tags     = [digitalocean_tag.base.id, digitalocean_tag.database.id]

  user_data = templatefile("${path.module}/../../shared/cloud-init/postgres.yaml.tftpl", {
    db_name        = var.db_name
    db_user        = var.db_user
    db_password    = var.db_password
    vpc_ip_range   = local.config.cluster_ip_range
    private_ip_cmd = local.metadata_private_ip_cmd
  })
}

# Redis Sentinel cluster: one master plus (redis_nodes - 1) replicas, every node
# running redis-server + redis-sentinel (see shared/cloud-init/redis.yaml.tftpl).
# Two resources rather than one with count: a replica needs the master's private
# IP in its cloud-init, and a resource cannot reference its own index 0.
resource "digitalocean_droplet" "redis_master" {
  name     = "redis-1"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [data.digitalocean_ssh_key.default.id]
  tags     = [digitalocean_tag.base.id, digitalocean_tag.redis.id]

  user_data = templatefile("${path.module}/../../shared/cloud-init/redis.yaml.tftpl", {
    is_master         = true
    master_ip         = "" # the master resolves its own private IP at boot
    master_name       = local.redis_master_name
    quorum            = local.redis_sentinel_quorum
    redis_password    = var.redis_password
    sentinel_password = var.redis_sentinel_password
    private_ip_cmd    = local.metadata_private_ip_cmd
  })
}

resource "digitalocean_droplet" "redis_replica" {
  count    = local.redis_nodes - 1
  name     = "redis-${count.index + 2}"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [data.digitalocean_ssh_key.default.id]
  tags     = [digitalocean_tag.base.id, digitalocean_tag.redis.id]

  user_data = templatefile("${path.module}/../../shared/cloud-init/redis.yaml.tftpl", {
    is_master         = false
    master_ip         = digitalocean_droplet.redis_master.ipv4_address_private
    master_name       = local.redis_master_name
    quorum            = local.redis_sentinel_quorum
    redis_password    = var.redis_password
    sentinel_password = var.redis_sentinel_password
    private_ip_cmd    = local.metadata_private_ip_cmd
  })
}
