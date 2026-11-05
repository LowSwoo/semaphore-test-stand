output "webhook_urls" {
  description = "Integration webhook URLs (POST to trigger the survey-vars-all-types template)."
  value = {
    all_values    = semaphoreui_integration_alias.all_values.url
    required_only = semaphoreui_integration_alias.required_only.url
    no_values     = semaphoreui_integration_alias.no_values.url
    token_auth    = semaphoreui_integration_alias.token_auth.url
    hmac_auth     = semaphoreui_integration_alias.hmac_auth.url
  }
}
