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
  description = "Address space of the VPC (from config)"
  value       = var.vnet.address_space
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = var.vnet.subnet.create ? google_compute_subnetwork.subnet[0].id : data.google_compute_subnetwork.subnet[0].id
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = var.vnet.subnet.name
}

output "subnet_prefix" {
  description = "IP CIDR range of the subnet"
  value       = var.vnet.subnet.create ? google_compute_subnetwork.subnet[0].ip_cidr_range : data.google_compute_subnetwork.subnet[0].ip_cidr_range
}

output "app_gw_subnet_id" {
  description = "ID of the App Gateway / proxy subnet"
  value       = var.vnet.app_gw_subnet.create ? google_compute_subnetwork.app_gw_subnet[0].id : data.google_compute_subnetwork.app_gw_subnet[0].id
}

output "app_gw_subnet_name" {
  description = "Name of the App Gateway / proxy subnet"
  value       = var.vnet.app_gw_subnet.name
}

output "app_gw_subnet_prefix" {
  description = "IP CIDR range of the App Gateway / proxy subnet"
  value       = var.vnet.app_gw_subnet.create ? google_compute_subnetwork.app_gw_subnet[0].ip_cidr_range : data.google_compute_subnetwork.app_gw_subnet[0].ip_cidr_range
}

# GCP Shared VPC: host project ID when this VPC is a Shared VPC host.
output "shared_vpc_host_project_id" {
  description = "Project ID of the Shared VPC host (only set when shared_vpc_host = true)"
  value       = var.vnet.create && try(var.vnet.shared_vpc_host, false) ? google_compute_shared_vpc_host_project.host[0].project : null
}
