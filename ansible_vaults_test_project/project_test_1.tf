resource "semaphoreui_project" "test_1" {
  name = "Test 1"
}

resource "semaphoreui_project_key" "semaphore_test_stand" {
  project_id = semaphoreui_project.test_1.id
  name       = "semaphore_test_stand"

  ssh = {
    private_key = file("${path.module}/../workspaces/default/id_rsa")
    # passphrase  = "123456"
  }
}

resource "semaphoreui_project_repository" "semaphore_test_stand" {
  project_id = semaphoreui_project.test_1.id
  name       = "semaphore-test-stand-tests"
  url        = "git@github.com:semaphoreui/semaphore-test-stand-tests.git"
  branch     = "main"
  ssh_key_id = semaphoreui_project_key.semaphore_test_stand.id
}

resource "semaphoreui_project_key" "none" {
  project_id = semaphoreui_project.test_1.id
  name       = "none"
  none       = {}
}

resource "semaphoreui_project_key" "vault_default" {
  project_id = semaphoreui_project.test_1.id
  name       = "vault_default"

  login_password = {
    login    = ""
    password = "defaultpass"
  }
}

resource "semaphoreui_project_key" "vault_1" {
  project_id = semaphoreui_project.test_1.id
  name       = "vault_1"

  login_password = {
    login    = ""
    password = "pass1"
  }
}

resource "semaphoreui_project_key" "vault_2" {
  project_id = semaphoreui_project.test_1.id
  name       = "vault_2"

  login_password = {
    login    = ""
    password = "pass2"
  }
}

resource "semaphoreui_project_inventory" "localhost" {
  project_id = semaphoreui_project.test_1.id
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
  project_id = semaphoreui_project.test_1.id
  name       = "default"
}

resource "semaphoreui_project_template" "multiple_vault_passwords" {
  project_id     = semaphoreui_project.test_1.id
  environment_id = semaphoreui_project_environment.default.id
  inventory_id   = semaphoreui_project_inventory.localhost.id
  repository_id  = semaphoreui_project_repository.semaphore_test_stand.id
  name           = "multiple-vault-passwords"
  playbook       = "multiple-vault-passwords/test.yml"

  vaults = [
    {
      name = ""
      password = {
        vault_key_id = semaphoreui_project_key.vault_default.id
      }
    },
    {
      name = "vault1"
      password = {
        vault_key_id = semaphoreui_project_key.vault_1.id
      }
    },
    {
      name = "vault2"
      password = {
        vault_key_id = semaphoreui_project_key.vault_2.id
      }
    },
  ]
}

resource "semaphoreui_project_template" "survey_variables" {
  project_id     = semaphoreui_project.test_1.id
  environment_id = semaphoreui_project_environment.default.id
  inventory_id   = semaphoreui_project_inventory.localhost.id
  repository_id  = semaphoreui_project_repository.semaphore_test_stand.id
  name           = "survey-vars"
  app            = "bash"
  playbook       = "survey-vars/run-test.sh"

  survey_vars = [
    {
      name  = "app_version"
      title = "App version"
      type     = "string"
      required = true
    },
    {
      name  = "secret_key"
      title = "Secret key"
      type  = "secret"
      required = true
    },
    {
      name  = "target_env"
      title = "Target environment"
      type  = "enum"
      required = true
      enum_values = {
        "Dev" = "dev"
        "Staging" = "staging"
        "Production" = "prod"
      }
    },
  ]
}
