# Resources that moved into the shared modules (modules/do/*). Keeps the
# droplets of stands created before the move instead of replacing them.
moved {
  from = digitalocean_droplet.cluster
  to   = module.semaphore.digitalocean_droplet.node
}

moved {
  from = digitalocean_droplet.postgres
  to   = module.postgres.digitalocean_droplet.postgres
}

moved {
  from = digitalocean_droplet.redis_master
  to   = module.redis.digitalocean_droplet.master
}

moved {
  from = digitalocean_droplet.redis_replica
  to   = module.redis.digitalocean_droplet.replica
}
