# Bash template that prints every survey variable it receives.
# Script: survey-vars-all-types/print-vars.sh in semaphore-test-stand-tests.
resource "semaphoreui_project_template" "survey_vars_all_types" {
  project_id     = semaphoreui_project.survey_vars.id
  environment_id = semaphoreui_project_environment.default.id
  inventory_id   = semaphoreui_project_inventory.localhost.id
  repository_id  = semaphoreui_project_repository.semaphore_test_stand.id
  name           = "survey-vars-all-types"
  app            = "bash"
  playbook       = "survey-vars-all-types/print-vars.sh"
  description    = "Prints all survey variables (string / integer / secret / enum, required and optional)"

  survey_vars = [
    # --- string ---
    {
      name     = "str_required"
      title    = "String (required)"
      type     = "string"
      required = true
    },
    {
      name  = "str_optional"
      title = "String (optional)"
      type  = "string"
    },
    {
      name        = "str_described"
      title       = "String with description"
      description = "Optional string; free text, spaces and special characters allowed"
      type        = "string"
    },

    # --- integer ---
    {
      name     = "int_required"
      title    = "Integer (required)"
      type     = "integer"
      required = true
    },
    {
      name  = "int_optional"
      title = "Integer (optional)"
      type  = "integer"
    },

    # --- secret ---
    {
      name     = "secret_required"
      title    = "Secret (required)"
      type     = "secret"
      required = true
    },
    {
      name  = "secret_optional"
      title = "Secret (optional)"
      type  = "secret"
    },

    # --- enum ---
    {
      name     = "enum_required"
      title    = "Enum (required)"
      type     = "enum"
      required = true
      enum_values = {
        "Development" = "dev"
        "Staging"     = "staging"
        "Production"  = "prod"
      }
    },
    {
      name  = "enum_optional"
      title = "Enum (optional)"
      type  = "enum"
      enum_values = {
        "Red"   = "red"
        "Green" = "green"
        "Blue"  = "blue"
      }
    },
  ]
}
