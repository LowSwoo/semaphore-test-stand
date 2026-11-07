output "webhook_url" {
  description = "Webhook URL of the survey-vars integration (POST to trigger the survey-vars-all-types template)."
  value       = semaphoreui_integration_alias.survey_vars.url
}
