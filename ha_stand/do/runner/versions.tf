terraform {
  required_version = ">= 1.5"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
    semaphoreui = {
      source  = "semaphoreui/semaphore"
      version = ">= 0.3.4"
    }
  }
}
