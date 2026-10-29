# Groups the stand's droplets in its own DigitalOcean project.
resource "digitalocean_project" "main" {
  name        = local.prefix
  description = "Semaphore UI SSO stand"
  purpose     = "Web Application"
  environment = "Development"
}

resource "digitalocean_project_resources" "main" {
  project = digitalocean_project.main.id
  resources = concat(
    module.semaphore.urns,
    [module.postgres.urn, module.idp.urn],
  )
}
