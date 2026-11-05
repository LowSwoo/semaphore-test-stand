resource "semaphoreui_project" "survey_vars" {
  name = "Survey Vars"
}

resource "semaphoreui_project_key" "none" {
  project_id = semaphoreui_project.survey_vars.id
  name       = "none"
  none       = {}
}

resource "semaphoreui_project_key" "semaphore_test_stand" {
  project_id = semaphoreui_project.survey_vars.id
  name       = "semaphore_test_stand"

  ssh = {
    private_key = file("${path.module}/../workspaces/default/id_rsa")
  }
}

resource "semaphoreui_project_repository" "semaphore_test_stand" {
  project_id = semaphoreui_project.survey_vars.id
  name       = "semaphore-test-stand-tests"
  url        = "git@github.com:semaphoreui/semaphore-test-stand-tests.git"
  branch     = "main"
  ssh_key_id = semaphoreui_project_key.semaphore_test_stand.id
}

resource "semaphoreui_project_inventory" "localhost" {
  project_id = semaphoreui_project.survey_vars.id
  name       = "localhost"
  ssh_key_id = semaphoreui_project_key.none.id

  static = {
    inventory = <<-EOT
      [local]
      localhost ansible_connection=local
    EOT
  }
}

resource "semaphoreui_project_environment" "default" {
  project_id = semaphoreui_project.survey_vars.id
  name       = "default"
}
