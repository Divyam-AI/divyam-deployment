output "storage_account_name" {
  description = "The name of the Azure Storage Account"
  value       = azurerm_storage_account.terraform.name
}

output "storage_account_id" {
  description = "The resource ID of the Azure Storage Account"
  value       = azurerm_storage_account.terraform.id
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint for the storage account"
  value       = azurerm_storage_account.terraform.primary_blob_endpoint
}

output "storage_container_name" {
  description = "The name of the blob container"
  value       = azurerm_storage_container.container.name
}

output "storage_container_url" {
  description = "The full URL to the private blob container"
  value       = "${azurerm_storage_account.terraform.primary_blob_endpoint}${azurerm_storage_container.container.name}"
}

output "backend_config" {
  description = "Values needed to configure the Terraform backend"
  value = {
    resource_group_name  = var.resource_group_name
    storage_account_name = azurerm_storage_account.terraform.name
    container_name       = azurerm_storage_container.container.name
    key                  = "terraform.tfstate"
  }
}