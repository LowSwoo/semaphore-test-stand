locals {
  # Sub-zone delegated to Google Cloud DNS (NS records added in the parent's DNS).
  dns_zone = "${var.prefix}.${var.parent_domain}"
  # Public HTTPS hostname for the load balancer.
  lb_fqdn = "${var.lb_subdomain}.${local.dns_zone}"
}

# Delegated sub-zone, managed in Google Cloud DNS. Its assigned nameservers are
# delegated from the parent zone (see cloudflare.tf).
resource "google_dns_managed_zone" "main" {
  name        = replace(local.dns_zone, ".", "-")
  dns_name    = "${local.dns_zone}."
  description = "Semaphore UI cluster delegated zone"

  depends_on = [google_project_service.dns]
}

# Google-managed certificate. Google provisions and auto-renews it once the
# load balancer hostname resolves to the LB IP (validation happens via the LB).
resource "google_compute_managed_ssl_certificate" "main" {
  name = "${var.prefix}-cert"

  managed {
    domains = [local.lb_fqdn]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.compute]
}

# Point the load balancer hostname at the load balancer IP.
resource "google_dns_record_set" "lb" {
  managed_zone = google_dns_managed_zone.main.name
  name         = "${local.lb_fqdn}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb.address]
}
