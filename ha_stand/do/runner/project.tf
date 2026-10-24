resource "digitalocean_project" "main" {
  count       = local.no_server ? 1 : 0
  name        = local.prefix
  description = "Semaphore UI cluster"
  purpose     = "Web Application"
  environment = "Development"
}


data "digitalocean_project" "main" {
  count     = local.no_server ? 0 : 1
  name = local.prefix
}

resource "digitalocean_project_resources" "main" {
  project   =  local.no_server ? digitalocean_project.main[0].id : data.digitalocean_project.main[0].id
  resources = [for d in digitalocean_droplet.runner : d.urn]
}