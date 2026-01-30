output "load_balancer_ip" {
  value = var.create_public_lb ? data.google_compute_global_address.static_ip[0].address : google_compute_address.internal[0].address
}

output "load_balancer_type" {
  value = var.create_public_lb ? "External HTTPS Load Balancer" : "Internal HTTPS Load Balancer"
}

output "load_balancer_redirects_http_to_https" {
  value = var.ssl_certificate_id != null
}