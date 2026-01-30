output "proxy_only_subnet_name" {
  description = "The name of the created proxy-only subnet."
  value       = google_compute_subnetwork.proxy_only_subnet.name
}

output "proxy_only_subnet_self_link" {
  description = "The self_link of the created proxy-only subnet."
  value       = google_compute_subnetwork.proxy_only_subnet.self_link
}

output "proxy_only_subnet_ip_cidr_range" {
  description = "The primary IP CIDR range of the created proxy-only subnet."
  value       = google_compute_subnetwork.proxy_only_subnet.ip_cidr_range
}
