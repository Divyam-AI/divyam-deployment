output "address_name" {
  description = "The name of the global static address."
  value       = var.enabled ? google_compute_global_address.static_address.name : ""
}

output "address_ip" {
  description = "The allocated IP address."
  value       = var.enabled ? google_compute_global_address.static_address.address : ""
}

output "dashboard_address_name" {
  description = "The name of the global static address for usage dashboard."
  value       = var.enabled ? google_compute_global_address.dashboard_static_address.name : ""
}

output "dashboard_address_ip" {
  description = "The allocated IP address for usage dashboard."
  value       = var.enabled ? google_compute_global_address.dashboard_static_address.address : ""
}

output "test_address_name" {
  description = "The name of the test global static address."
  value       = var.enabled ? google_compute_global_address.test_static_address.name : ""
}

output "test_address_ip" {
  description = "The allocated test IP address."
  value       = var.enabled ? google_compute_global_address.test_static_address.address : ""
}