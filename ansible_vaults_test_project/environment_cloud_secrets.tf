resource "semaphoreui_project_environment" "cloud_secrets" {
  project_id = semaphoreui_project.test_1.id
  name       = "cloud-secrets"

  variables = {
    cloud_provider_hint = "fake-multi-cloud-demo"
  }

  environment = {
    AWS_DEFAULT_REGION = "us-east-1"
  }

  secrets = [
    {
      name  = "AWS_ACCESS_KEY_ID"
      type  = "env"
      value = "AKIAFAKE00000000001"
    },
    {
      name  = "AWS_SECRET_ACCESS_KEY"
      type  = "env"
      value = "fake-aws-secret-access-key-32chars!!"
    },
    {
      name  = "ARM_CLIENT_ID"
      type  = "var"
      value = "00000000-0000-0000-0000-00000000azure"
    },
    {
      name  = "ARM_CLIENT_SECRET"
      type  = "var"
      value = "fake-azure-client-secret-value"
    },
    {
      name  = "ARM_TENANT_ID"
      type  = "var"
      value = "11111111-1111-1111-1111-111111111111"
    },
    {
      name  = "GCP_PROJECT_ID"
      type  = "var"
      value = "fake-gcp-demo-project"
    },
    {
      name  = "GCP_SERVICE_ACCOUNT_EMAIL"
      type  = "var"
      value = "fake-sa@fake-gcp-demo-project.iam.gserviceaccount.com"
    },
  ]
}

resource "semaphoreui_project_template" "var_group_with_secrets" {
  project_id     = semaphoreui_project.test_1.id
  environment_id = semaphoreui_project_environment.cloud_secrets.id
  inventory_id   = semaphoreui_project_inventory.localhost.id
  repository_id  = semaphoreui_project_repository.semaphore_test_stand.id
  name           = "var-group-with-secrets"
  app            = "ansible"
  playbook       = "var-group-with-secrets/test.yml"
  description    = "Ansible playbook: assert variable group env/var secrets"
}

resource "semaphoreui_project_template" "var_group_with_secrets_bash" {
  project_id     = semaphoreui_project.test_1.id
  environment_id = semaphoreui_project_environment.cloud_secrets.id
  inventory_id   = semaphoreui_project_inventory.localhost.id
  repository_id  = semaphoreui_project_repository.semaphore_test_stand.id
  name           = "var-group-with-secrets-bash"
  app            = "bash"
  playbook       = "var-group-with-secrets/run-test.sh"
  description    = "Bash script: same checks as test.yml (aws/azure/gcp roles)"
}
