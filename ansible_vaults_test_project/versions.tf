terraform {
  required_version = ">= 1.0"

  required_providers {
    semaphoreui = {
      source  = "semaphoreui/semaphore"
      version = "~> 0.1"
    }
  }
}
