output "project_id" {
  description = "The GCP project ID used."
  value       = var.project_id
}

output "router_name" {
  description = "The name of the Cloud Router."
  value       = var.enabled ? google_compute_router.divyam_router_egress_nat_router.name : ""
}

output "nat_config_name" {
  description = "The name of the NAT configuration."
  value       = var.enabled ? google_compute_router_nat.nat_config.name : ""
}
