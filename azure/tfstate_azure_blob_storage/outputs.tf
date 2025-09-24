output "storage_account_name" {
  description = "The name of the Azure Storage Account"
  value = (var.create ? azurerm_storage_account.terraform[0].name
  : data.azurerm_storage_account.terraform[0].name)
}

output "storage_account_id" {
  description = "The resource ID of the Azure Storage Account"
  value = (var.create ? azurerm_storage_account.terraform[0].id
  : data.azurerm_storage_account.terraform[0].id)
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint for the storage account"
  value = (var.create ? azurerm_storage_account.terraform[0].primary_blob_endpoint
  : data.azurerm_storage_account.terraform[0].primary_blob_endpoint)
}

output "storage_container_name" {
  description = "The name of the blob container"
  value = (var.create ? azurerm_storage_container.container[0].name
  : data.azurerm_storage_container.container[0].name)
}

output "storage_container_url" {
  description = "The full URL to the private blob container"
  value = (var.create ? "${azurerm_storage_account.terraform[0].primary_blob_endpoint}${azurerm_storage_container.container[0].name}"
  : "${data.azurerm_storage_account.terraform[0].primary_blob_endpoint}${data.azurerm_storage_container.container[0].name}")
}

output "backend_config" {
  description = "Values needed to configure the Terraform backend"
  value = {
    resource_group_name = var.resource_group_name
    storage_account_name = (var.create ? azurerm_storage_account.terraform[0].name
    : data.azurerm_storage_account.terraform[0].name)
    container_name = (var.create ? azurerm_storage_container.container[0].name
    : data.azurerm_storage_container.container[0].name)
    key = "terraform.tfstate"
  }
}