output "resource_group_name" {
  description = "Created or existing Azure resource group name"
  value       = local.rg.name
}

output "resource_group_id" {
  description = "Azure resource group ID"
  value       = local.rg.id
}

output "location" {
  description = "Resource group location (region)"
  value       = local.rg.location
}
