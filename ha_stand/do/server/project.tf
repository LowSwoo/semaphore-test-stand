# Groups the deployment in its own DigitalOcean project. Only resources that
# support project assignment (droplets, load balancers) are listed here — VPCs,
# firewalls, tags and SSH keys are account/region-scoped and cannot be bound.
resource "digitalocean_project" "main" {
  name        = local.prefix
  description = "Semaphore UI cluster"
  purpose     = "Web Application"
  environment = "Development"
}

resource "digitalocean_project_resources" "main" {
  project = digitalocean_project.main.id
  resources = concat(
    module.semaphore.urns,
    module.redis.urns,
    [
      module.postgres.urn,
      digitalocean_loadbalancer.main.urn,
    ],
  )
}