#----------------------------------------------
# Generate deployment configuration for all
# Divyam components.
#----------------------------------------------
locals {
  install_config = read_terragrunt_config("${get_repo_root()}/azure/config/config-merge.hcl").locals.install_config
  common_tags = try(local.install_config.common_tags, {})

  location                     = local.install_config.location
  resource_group_name          = local.install_config.resource_group_name
  storage_container_name       = local.install_config.tfstate_azure_blob_storage.storage_container_name
  tfstate_storage_account_name = local.install_config.tfstate_azure_blob_storage.storage_account_name
  resource_name_prefix         = local.install_config.resource_name_prefix
  environment = local.install_config.environment

  # Shared remote backend config
  azure_backend = {
    resource_group_name  = "${local.resource_group_name}"
    storage_account_name = "${local.tfstate_storage_account_name}"
    container_name       = "${local.storage_container_name}"
    key                  = "${local.install_config.env_name}/${local.location}/${path_relative_to_include()}/terraform.tfstate"
  }
}

# Automatically generate provider block in every module
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.45.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "${local.install_config.subscription_id}"
  tenant_id       = "${local.install_config.tenant_id}"
}
EOF
}

remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    resource_group_name  = local.azure_backend.resource_group_name
    storage_account_name = local.azure_backend.storage_account_name
    container_name       = local.azure_backend.container_name
    key                  = local.azure_backend.key
  }
}

# Shared inputs available to all child modules
inputs = {
  location               = local.location
  resource_group_name    = local.resource_group_name
  storage_container_name = local.storage_container_name
  environment            = local.environment
  resource_name_prefix   = local.resource_name_prefix
  common_tags            = local.common_tags
}
