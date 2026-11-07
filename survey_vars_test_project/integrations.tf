# Integration (incoming webhook, no auth) that runs the survey-vars-all-types
# template. Survey values are taken from the webhook request by extractors
# (integration extract values): each extractor writes one survey variable.
#
# Example request body:
#   {
#     "str_required": "hello",
#     "str_optional": "optional",
#     "str_described": "spaces & special chars",
#     "int_required": 42,
#     "int_optional": 7,
#     "secret_required": "s3cr3t",
#     "enum_required": "staging",
#     "options": { "color": "green" }
#   }
# plus header  X-Secret-Optional: <value>  for secret_optional.

resource "semaphoreui_project_integration" "survey_vars" {
  project_id  = semaphoreui_project.survey_vars.id
  template_id = semaphoreui_project_template.survey_vars_all_types.id
  name        = "survey-vars"

  task_params = {
    message = "integration: survey vars from webhook"
  }
}

resource "semaphoreui_integration_alias" "survey_vars" {
  project_id     = semaphoreui_project.survey_vars.id
  integration_id = semaphoreui_project_integration.survey_vars.id
}

locals {
  # variable (survey var name) => where to take the value from.
  #   source = body   -> JSON body, `key` is a gojsonq path (dots for nesting)
  #   source = header -> HTTP header named `key`
  survey_extractors = {
    str_required    = { source = "body", key = "str_required" }
    str_optional    = { source = "body", key = "str_optional" }
    str_described   = { source = "body", key = "str_described" }
    int_required    = { source = "body", key = "int_required" }
    int_optional    = { source = "body", key = "int_optional" }
    secret_required = { source = "body", key = "secret_required" }
    secret_optional = { source = "header", key = "X-Secret-Optional" }
    enum_required   = { source = "body", key = "enum_required" }
    enum_optional   = { source = "body", key = "options.color" }
  }
}

resource "restapi_object" "survey_extractor" {
  for_each = local.survey_extractors

  path = "/project/${semaphoreui_project.survey_vars.id}/integrations/${semaphoreui_project_integration.survey_vars.id}/values"

  data = jsonencode(merge(
    {
      integration_id = semaphoreui_project_integration.survey_vars.id
      name           = each.key
      value_source   = each.value.source
      key            = each.value.key
      variable       = each.key
      # "environment" puts the value into the task's extra vars, which is where
      # Semaphore reads survey variable values from.
      variable_type = "environment"
    },
    each.value.source == "body" ? { body_data_type = "json" } : {},
  ))

  # The API requires the value ID in the PUT body, which restapi does not send,
  # so any change recreates the extractor instead of updating it.
  force_new = ["integration_id", "name", "value_source", "body_data_type", "key", "variable", "variable_type"]
}
