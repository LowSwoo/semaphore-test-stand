# Global external HTTPS load balancer fronting the Semaphore UI instances.
# Terminates TLS with a Google-managed certificate (see certificate.tf) and
# redirects HTTP -> HTTPS. Forwards plain HTTP to Semaphore on :3000.

resource "google_compute_global_address" "lb" {
  name = "${var.prefix}-lb-ip"

  depends_on = [google_project_service.compute]
}

resource "google_compute_health_check" "main" {
  name                = "${var.prefix}-hc"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 3
  unhealthy_threshold = 3

  http_health_check {
    port         = 3000
    request_path = "/api/ping"
  }

  depends_on = [google_project_service.compute]
}

# Unmanaged instance group holding the UI nodes, exposing :3000 as a named port.
resource "google_compute_instance_group" "cluster" {
  name      = "${var.prefix}-ig"
  zone      = var.zone
  instances = [for i in google_compute_instance.cluster : i.self_link]

  named_port {
    name = "http3000"
    port = 3000
  }
}

resource "google_compute_backend_service" "main" {
  name                  = "${var.prefix}-backend"
  protocol              = "HTTP"
  port_name             = "http3000"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.main.id]

  backend {
    group           = google_compute_instance_group.cluster.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "main" {
  name            = "${var.prefix}-urlmap"
  default_service = google_compute_backend_service.main.id
}

resource "google_compute_target_https_proxy" "main" {
  name             = "${var.prefix}-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [google_compute_managed_ssl_certificate.main.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.prefix}-https-fr"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.lb.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.main.id
}

# --- HTTP -> HTTPS redirect -------------------------------------------------
resource "google_compute_url_map" "redirect" {
  name = "${var.prefix}-redirect"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }

  depends_on = [google_project_service.compute]
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${var.prefix}-http-proxy"
  url_map = google_compute_url_map.redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.prefix}-http-fr"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.lb.id
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
}
