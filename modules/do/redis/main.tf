# Redis Sentinel cluster: one master plus (nodes - 1) replicas, every node
# running redis-server + redis-sentinel (see templates/redis.yaml.tftpl).
# Two resources rather than one with count: a replica needs the master's private
# IP in its cloud-init, and a resource cannot reference its own index 0.
locals {
  # DigitalOcean metadata endpoint for the droplet's own private IP.
  metadata_private_ip_cmd = "curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address"

  # All Sentinel endpoints (master first), handed to the Semaphore nodes as ha.redis_sentinel.addrs.
  private_ips    = concat([digitalocean_droplet.master.ipv4_address_private], digitalocean_droplet.replica[*].ipv4_address_private)
  sentinel_addrs = [for ip in local.private_ips : "${ip}:26379"]
}

resource "digitalocean_droplet" "master" {
  name     = "redis-1"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = var.vpc_uuid

  ssh_keys = var.ssh_keys
  tags     = var.tags

  user_data = templatefile("${path.module}/templates/redis.yaml.tftpl", {
    is_master         = true
    master_ip         = "" # the master resolves its own private IP at boot
    master_name       = var.master_name
    quorum            = var.sentinel_quorum
    redis_password    = var.redis_password
    sentinel_password = var.sentinel_password
    private_ip_cmd    = local.metadata_private_ip_cmd
  })
}

resource "digitalocean_droplet" "replica" {
  count    = var.nodes - 1
  name     = "redis-${count.index + 2}"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = var.vpc_uuid

  ssh_keys = var.ssh_keys
  tags     = var.tags

  user_data = templatefile("${path.module}/templates/redis.yaml.tftpl", {
    is_master         = false
    master_ip         = digitalocean_droplet.master.ipv4_address_private
    master_name       = var.master_name
    quorum            = var.sentinel_quorum
    redis_password    = var.redis_password
    sentinel_password = var.sentinel_password
    private_ip_cmd    = local.metadata_private_ip_cmd
  })
}
