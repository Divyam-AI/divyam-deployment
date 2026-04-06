output "load_balancer_ip" {
  description = "IP address of the load balancer (public or internal)"
  value       = local.has_public_static_ip ? local.public_ip_addr : (var.create_public_lb ? null : google_compute_address.internal[0].address)
}

output "load_balancer_type" {
  description = "Type of load balancer"
  value       = var.create_public_lb ? "External HTTPS Load Balancer" : "Internal HTTPS Load Balancer"
}

output "load_balancer_redirects_http_to_https" {
  description = "True if HTTP is redirected to HTTPS"
  value       = local.ssl_certificate_id != null
}

output "ssl_certificate_name" {
  description = "Name of the SSL certificate (managed cert when create_ssl_cert and tls_enabled; for reference by GKE/helm)"
  value       = local.create_managed_cert ? google_compute_managed_ssl_certificate.lb_cert[0].name : (var.ssl_cert_name != null ? var.ssl_cert_name : null)
}

output "cloud_armor_policy_id" {
  description = "Cloud Armor security policy ID (created in-module or fetched by name)"
  value       = local.security_policy_id
}
