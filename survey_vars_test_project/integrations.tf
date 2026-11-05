# Integrations (incoming webhooks) that run the survey-vars-all-types template.
# Survey values are supplied via task_params.environment (JSON object).
# Each integration gets an alias; the webhook URLs are exported as outputs.

locals {
  survey_values_all = {
    str_required    = "from integration"
    str_optional    = "optional value"
    str_described   = "spaces & special chars: !@#$%^*()"
    int_required    = 42
    int_optional    = 7
    secret_required = "fake-integration-secret"
    secret_optional = "fake-optional-secret"
    enum_required   = "staging"
    enum_optional   = "green"
  }

  survey_values_required_only = {
    str_required    = "required only"
    int_required    = 1
    secret_required = "fake-required-secret"
    enum_required   = "prod"
  }
}

# Key used by the token / hmac integrations to verify incoming requests.
resource "semaphoreui_project_key" "webhook_secret" {
  project_id = semaphoreui_project.survey_vars.id
  name       = "webhook_secret"

  login_password = {
    login    = ""
    password = var.webhook_secret
  }
}

# 1. No auth, all survey vars set.
resource "semaphoreui_project_integration" "all_values" {
  project_id  = semaphoreui_project.survey_vars.id
  template_id = semaphoreui_project_template.survey_vars_all_types.id
  name        = "survey-all-values"

  task_params = {
    message     = "integration: all survey vars"
    environment = jsonencode(local.survey_values_all)
  }
}

# 2. No auth, only required survey vars set (optional ones must be <unset>).
resource "semaphoreui_project_integration" "required_only" {
  project_id  = semaphoreui_project.survey_vars.id
  template_id = semaphoreui_project_template.survey_vars_all_types.id
  name        = "survey-required-only"

  task_params = {
    message     = "integration: required survey vars only"
    environment = jsonencode(local.survey_values_required_only)
  }
}

# 3. No auth, no values at all (shows how missing required vars are handled).
resource "semaphoreui_project_integration" "no_values" {
  project_id  = semaphoreui_project.survey_vars.id
  template_id = semaphoreui_project_template.survey_vars_all_types.id
  name        = "survey-no-values"

  task_params = {
    message = "integration: no survey vars"
  }
}

# 4. Token auth (header value must equal var.webhook_secret), all values.
resource "semaphoreui_project_integration" "token_auth" {
  project_id     = semaphoreui_project.survey_vars.id
  template_id    = semaphoreui_project_template.survey_vars_all_types.id
  name           = "survey-token-auth"
  auth_method    = "token"
  auth_secret_id = semaphoreui_project_key.webhook_secret.id
  auth_header    = "X-Semaphore-Token"

  task_params = {
    message     = "integration: token auth"
    environment = jsonencode(local.survey_values_all)
  }
}

# 5. HMAC auth (X-Hub-Signature-256 = sha256 HMAC of body), all values.
resource "semaphoreui_project_integration" "hmac_auth" {
  project_id     = semaphoreui_project.survey_vars.id
  template_id    = semaphoreui_project_template.survey_vars_all_types.id
  name           = "survey-hmac-auth"
  auth_method    = "hmac"
  auth_secret_id = semaphoreui_project_key.webhook_secret.id
  auth_header    = "X-Hub-Signature-256"

  task_params = {
    message     = "integration: hmac auth"
    environment = jsonencode(local.survey_values_all)
  }
}

resource "semaphoreui_integration_alias" "all_values" {
  project_id     = semaphoreui_project.survey_vars.id
  integration_id = semaphoreui_project_integration.all_values.id
}

resource "semaphoreui_integration_alias" "required_only" {
  project_id     = semaphoreui_project.survey_vars.id
  integration_id = semaphoreui_project_integration.required_only.id
}

resource "semaphoreui_integration_alias" "no_values" {
  project_id     = semaphoreui_project.survey_vars.id
  integration_id = semaphoreui_project_integration.no_values.id
}

resource "semaphoreui_integration_alias" "token_auth" {
  project_id     = semaphoreui_project.survey_vars.id
  integration_id = semaphoreui_project_integration.token_auth.id
}

resource "semaphoreui_integration_alias" "hmac_auth" {
  project_id     = semaphoreui_project.survey_vars.id
  integration_id = semaphoreui_project_integration.hmac_auth.id
}
