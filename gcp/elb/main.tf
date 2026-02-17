provider "google" {
  project = var.project_id
  region  = var.region
}

# Static Public IP
data "google_compute_global_address" "static_ip" {
  count = var.create_public_lb ? 1 : 0
  name  = var.static_ip_name
}

# Internal IP
resource "google_compute_address" "internal" {
  count        = var.create_public_lb ? 0 : 1
  name         = "${var.backend_service_name}-internal-lb-ip"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
  region       = var.region
}

resource "google_compute_health_check" "default" {
  name               = "${var.backend_service_name}-elb-health-check"
  check_interval_sec = 30
  timeout_sec        = 5
  healthy_threshold  = 3
  unhealthy_threshold = 3

  http_health_check {
    port               = 8000
    request_path       = "/status"
    proxy_header       = "NONE"
  }
}

# Get zonal NEGs
# data "google_compute_network_endpoint_group" "zonal_negs" {
#   for_each = toset(var.gke_neg_zones)
#   name     = var.gke_neg_names[index(var.gke_neg_zones, each.key)]
#   zone     = each.key
#   project  = var.project_id
# }

# Backend Service
resource "google_compute_backend_service" "default" {
  name                             = var.backend_service_name
  protocol                         = "HTTP"
  port_name                        = "http"
  load_balancing_scheme            = var.create_public_lb ? "EXTERNAL" : "INTERNAL_MANAGED"
  timeout_sec                      = 10
  enable_cdn                       = false
  connection_draining_timeout_sec = 0
  security_policy                  = var.cloud_armor_policy_id

  health_checks = [google_compute_health_check.default.self_link]

  dynamic "backend" {
    for_each = zipmap(var.gke_neg_zones, var.gke_neg_names)
    content {
      group = "projects/${var.project_id}/zones/${backend.key}/networkEndpointGroups/${backend.value}"
      balancing_mode  = "UTILIZATION"
      max_utilization = 0.8
    }
  }
}

# URL Maps
resource "google_compute_url_map" "default" {
  name            = "${var.backend_service_name}-gke-url-map"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_url_map" "http_redirect" {
  count = var.ssl_certificate_id != null ? 1 : 0
  name  = "${var.backend_service_name}-http-to-https-redirect-map"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

# Proxies
resource "google_compute_target_https_proxy" "https" {
  count             = var.ssl_certificate_id != null ? 1 : 0
  name              = "${var.target_proxy_name}-https"
  url_map           = google_compute_url_map.default.id
  ssl_certificates  = [var.ssl_certificate_id]
}

resource "google_compute_target_http_proxy" "http" {
  name    = "${var.target_proxy_name}-http"
  url_map = var.ssl_certificate_id != null ? google_compute_url_map.http_redirect[0].id : google_compute_url_map.default.id
}

# Forwarding Rules - Public
resource "google_compute_global_forwarding_rule" "https" {
  count       = var.create_public_lb && var.ssl_certificate_id != null ? 1 : 0
  name        = "${var.backend_service_name}-https-forwarding-rule"
  ip_address  = data.google_compute_global_address.static_ip[0].id
  port_range  = "443"
  target      = google_compute_target_https_proxy.https[0].id
  ip_protocol = "TCP"
}

resource "google_compute_global_forwarding_rule" "http" {
  count       = var.create_public_lb ? 1 : 0
  name        = "${var.backend_service_name}-http-forwarding-rule"
  ip_address  = data.google_compute_global_address.static_ip[0].id
  port_range  = "80"
  target      = google_compute_target_http_proxy.http.id
  ip_protocol = "TCP"
}

# Forwarding Rule - Internal
resource "google_compute_forwarding_rule" "internal" {
  count                 = var.create_public_lb ? 0 : 1
  name                  = var.ssl_certificate_id != null ? "internal-https-rule" : "internal-http-rule"
  load_balancing_scheme = "INTERNAL_MANAGED"
  backend_service       = google_compute_backend_service.default.id
  ip_protocol           = "TCP"
  ports                 = [var.ssl_certificate_id != null ? "443" : "80"]
  ip_address            = google_compute_address.internal[0].address
  network               = var.network
  subnetwork            = var.subnetwork
  region                = var.region
}