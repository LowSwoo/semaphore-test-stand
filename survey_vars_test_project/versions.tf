terraform {
  required_version = ">= 1.0"

  required_providers {
    semaphoreui = {
      source  = "semaphoreui/semaphore"
      version = "~> 0.1"
    }

    # Integration extract values are not supported by the semaphoreui provider
    # yet, so they are created directly through the Semaphore REST API.
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}
