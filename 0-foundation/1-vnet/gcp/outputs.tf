# Outputs match Azure 1-vnet for compatibility. app_gw_* are empty on GCP.

output "vnet_id" {
  description = "ID of the VPC network"
  value       = var.vnet.create ? google_compute_network.vpc[0].id : data.google_compute_network.vpc[0].id
}

output "vnet_name" {
  description = "Name of the VPC network"
  value       = var.vnet.create ? google_compute_network.vpc[0].name : data.google_compute_network.vpc[0].name
}

output "vnet_resource_group_name" {
  description = "Project ID (scope); analogous to Azure resource group name"
  value       = var.vnet.scope_name
}

output "vnet_address_space" {
  description = "Address space of the VPC (from config; GCP VPC has no single range)"
  value       = var.vnet.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = merge(
    { for name, subnet in google_compute_subnetwork.subnets : name => subnet.id },
    { for name, subnet in data.google_compute_subnetwork.existing_subnets : name => subnet.id }
  )
}

output "subnet_names" {
  description = "List of subnet names"
  value = concat(
    [for subnet in google_compute_subnetwork.subnets : subnet.name],
    [for subnet in data.google_compute_subnetwork.existing_subnets : subnet.name]
  )
}

output "subnet_prefixes" {
  description = "Map of subnet names to their IP CIDR ranges"
  value = merge(
    { for name, subnet in google_compute_subnetwork.subnets : name => subnet.ip_cidr_range },
    { for name, subnet in data.google_compute_subnetwork.existing_subnets : name => subnet.ip_cidr_range }
  )
}

# App Gateway subnets are Azure-only; empty for GCP.
output "app_gw_subnet_ids" {
  description = "Map of App Gateway subnet names to their IDs (empty for GCP)"
  value       = {}
}

output "app_gw_subnet_names" {
  description = "List of App Gateway subnet names (empty for GCP)"
  value       = []
}

output "app_gw_subnet_prefixes" {
  description = "Map of App Gateway subnet names to address prefixes (empty for GCP)"
  value       = {}
}
