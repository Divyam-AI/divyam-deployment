# External/Internal Load Balancer (GCP). Config from values/defaults.hcl divyam_load_balancer.
# Feature spec from gcp/elb.

locals {
  has_public_static_ip = var.create_public_lb  # Static IP is created in-module when public

  # DNS names for managed SSL cert (from divyam_load_balancer.router_dns and dashboard_dns).
  ssl_cert_domains   = compact([var.router_dns, var.dashboard_dns])
  create_managed_cert = var.create_ssl_cert && var.tls_enabled && var.ssl_certificate_id == null && var.ssl_cert_name != null && length(local.ssl_cert_domains) > 0
  ssl_certificate_id  = local.create_managed_cert ? google_compute_managed_ssl_certificate.lb_cert[0].id : var.ssl_certificate_id

  # Plan-time known: true when HTTPS will be used (existing cert or we're creating managed cert).
  https_enabled = var.ssl_certificate_id != null || local.create_managed_cert

  resource_names = {
    lb_ip           = coalesce(var.static_ip_name, "${var.backend_service_name}-ip")
    lb_cert         = coalesce(var.ssl_cert_name, "${var.backend_service_name}-lb-ssl-cert")
    internal_ip     = coalesce(var.private_ip_name, "${var.backend_service_name}-internal-lb-ip")
    health_check      = "${var.backend_service_name}-elb-health-check"
    backend_service   = var.backend_service_name
    url_map_default   = "${var.backend_service_name}-gke-url-map"
    url_map_redirect  = "${var.backend_service_name}-http-to-https-redirect-map"
    target_https      = "${var.target_proxy_name}-https"
    target_http       = "${var.target_proxy_name}-http"
    fr_https          = "${var.backend_service_name}-https-forwarding-rule"
    fr_http           = "${var.backend_service_name}-http-forwarding-rule"
    fr_internal       = (var.tls_enabled && local.https_enabled) ? "internal-https-rule" : "internal-http-rule"
  }
  rendered_tags_for = {
    for key, resource_name in local.resource_names : key => {
      for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", (lookup(merge(local.tag_context, { resource_name = resource_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")))
    }
  }
}

resource "google_compute_managed_ssl_certificate" "lb_cert" {
  count   = local.create_managed_cert ? 1 : 0
  name    = var.ssl_cert_name
  project = var.project_id

  labels = local.rendered_tags_for["lb_cert"]

  managed {
    domains = local.ssl_cert_domains
  }
}

# Create static public IP in-module when create_public_lb and not using existing (same as Azure app_gw).
resource "google_compute_global_address" "static_ip" {
  count   = var.create_public_lb && var.create_public_ip ? 1 : 0
  name    = coalesce(var.static_ip_name, "${var.backend_service_name}-ip")
  project = var.project_id

  labels = local.rendered_tags_for["lb_ip"]
}

data "google_compute_global_address" "existing" {
  count   = var.create_public_lb && !var.create_public_ip ? 1 : 0
  name    = var.static_ip_name
  project = var.project_id
}

locals {
  public_ip_id    = var.create_public_lb ? (var.create_public_ip ? google_compute_global_address.static_ip[0].id : data.google_compute_global_address.existing[0].id) : null
  public_ip_addr = var.create_public_lb ? (var.create_public_ip ? google_compute_global_address.static_ip[0].address : data.google_compute_global_address.existing[0].address) : null
}

# Fetch app-gateway subnet by name when using internal LB (not needed for public LB).
data "google_compute_subnetwork" "appgw" {
  count   = var.create_public_lb ? 0 : 1
  name    = var.app_gw_subnet_name
  region  = var.region
  project = var.project_id
}

locals {
  # From vnet config only; no defaults — fail if network_name or app_gw_subnet_name missing.
  network_self_link    = "projects/${var.project_id}/global/networks/${var.network_name}"
  subnetwork_self_link = var.create_public_lb ? null : data.google_compute_subnetwork.appgw[0].self_link
}

resource "google_compute_address" "internal" {
  count        = var.create_public_lb ? 0 : 1
  name         = coalesce(var.private_ip_name, "${var.backend_service_name}-internal-lb-ip")
  project      = var.project_id
  address_type = "INTERNAL"
  subnetwork   = data.google_compute_subnetwork.appgw[0].self_link
  region       = var.region
  address      = var.lb_ip

  labels = local.rendered_tags_for["internal_ip"]
}

resource "google_compute_health_check" "default" {
  name                = "${var.backend_service_name}-elb-health-check"
  project             = var.project_id
  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 3
  unhealthy_threshold = 3

  labels = local.rendered_tags_for["health_check"]

  http_health_check {
    port         = 8000
    request_path = "/status"
    proxy_header = "NONE"
  }
}

resource "google_compute_backend_service" "default" {
  name                              = var.backend_service_name
  project                           = var.project_id
  protocol                          = "HTTP"
  port_name                         = "http"
  load_balancing_scheme              = var.create_public_lb ? "EXTERNAL" : "INTERNAL_MANAGED"
  timeout_sec                        = 10
  enable_cdn                         = false
  connection_draining_timeout_sec    = 0
  security_policy                    = local.security_policy_id

  labels = local.rendered_tags_for["backend_service"]

  health_checks = [google_compute_health_check.default.self_link]

  dynamic "backend" {
    for_each = length(var.gke_neg_zones) > 0 ? zipmap(var.gke_neg_zones, var.gke_neg_names) : {}
    content {
      group             = "projects/${var.project_id}/zones/${backend.key}/networkEndpointGroups/${backend.value}"
      balancing_mode    = "UTILIZATION"
      max_utilization   = 0.8
    }
  }

}

resource "google_compute_url_map" "default" {
  name            = "${var.backend_service_name}-gke-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.default.id

  labels = local.rendered_tags_for["url_map_default"]
}

resource "google_compute_url_map" "http_redirect" {
  count    = local.https_enabled ? 1 : 0
  name     = "${var.backend_service_name}-http-to-https-redirect-map"
  project  = var.project_id

  labels = local.rendered_tags_for["url_map_redirect"]

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_https_proxy" "https" {
  count            = local.https_enabled ? 1 : 0
  name             = "${var.target_proxy_name}-https"
  project          = var.project_id
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [local.ssl_certificate_id]

  labels = local.rendered_tags_for["target_https"]
}

resource "google_compute_target_http_proxy" "http" {
  name    = "${var.target_proxy_name}-http"
  project = var.project_id
  url_map = local.https_enabled ? google_compute_url_map.http_redirect[0].id : google_compute_url_map.default.id

  labels = local.rendered_tags_for["target_http"]
}

resource "google_compute_global_forwarding_rule" "https" {
  count       = local.has_public_static_ip && local.https_enabled ? 1 : 0
  name        = "${var.backend_service_name}-https-forwarding-rule"
  project     = var.project_id
  ip_address  = local.public_ip_id
  port_range  = "443"
  target      = google_compute_target_https_proxy.https[0].id
  ip_protocol = "TCP"

  labels = local.rendered_tags_for["fr_https"]
}

resource "google_compute_global_forwarding_rule" "http" {
  count       = local.has_public_static_ip ? 1 : 0
  name        = "${var.backend_service_name}-http-forwarding-rule"
  project     = var.project_id
  ip_address  = local.public_ip_id
  port_range  = "80"
  target      = google_compute_target_http_proxy.http.id
  ip_protocol = "TCP"

  labels = local.rendered_tags_for["fr_http"]
}

resource "google_compute_forwarding_rule" "internal" {
  count                 = var.create_public_lb ? 0 : 1
  name                  = local.https_enabled ? "internal-https-rule" : "internal-http-rule"
  project               = var.project_id
  load_balancing_scheme  = "INTERNAL_MANAGED"
  backend_service       = google_compute_backend_service.default.id
  ip_protocol           = "TCP"
  ports                 = [local.https_enabled ? "443" : "80"]
  ip_address            = google_compute_address.internal[0].address
  network               = local.network_self_link
  subnetwork            = data.google_compute_subnetwork.appgw[0].self_link
  region                = var.region

  labels = local.rendered_tags_for["fr_internal"]
}
