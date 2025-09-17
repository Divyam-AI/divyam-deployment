locals {
  env_name = get_env("ENV", "dev")
  install_config = read_terragrunt_config("${get_repo_root()}/deployment/azure/envs/${local.env_name}/terragrunt.hcl").locals

  location            = local.install_config.location
  resource_group_name = local.install_config.resource_group_name
  storage_container_name = try(local.install_config.tf_state_storage_container_name, "tfstate")
  tfstate_storage_account_name = try(local.install_config.tf_state_storage_account_name, "divyam${local.env_name}tfstate")

  # Shared remote backend config
  azure_backend = {
    resource_group_name  = "${local.install_config.resource_group_name}"
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
      version = ">= 4.39.0"
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
  environment            = local.env_name
}
