resource "digitalocean_project" "main" {
  count       = local.no_server ? 1 : 0
  name        = local.prefix
  description = "Semaphore UI cluster"
  purpose     = "Web Application"
  environment = "Development"
}

# The project is created by the server module. Not read when the servers are
# known to be gone (skip_server): `terraform destroy` still reads data sources,
# and a missing project would abort the destroy before any droplet is removed.
data "digitalocean_project" "main" {
  count = local.no_server || var.skip_server ? 0 : 1
  name  = local.prefix
}

resource "digitalocean_project_resources" "main" {
  project   = local.no_server ? digitalocean_project.main[0].id : try(data.digitalocean_project.main[0].id, "")
  resources = [for d in digitalocean_droplet.runner : d.urn]
}
