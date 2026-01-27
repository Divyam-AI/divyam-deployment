#----------------------------------------------
# Azure Provider Configuration
# Contains: backend config, provider block, defaults
#----------------------------------------------

locals {
  # Environment variables for Azure
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "")
  tenant_id       = get_env("ARM_TENANT_ID", "")
  location        = get_env("LOCATION", "centralindia")
  env_name        = get_env("ENV", "dev")

  # Resource naming
  resource_group_name = get_env("AZURE_RESOURCE_GROUP", "")
  storage_account_name = "${replace(local.resource_group_name, "-", "")}tfstate"
  storage_container_name = "tfstate"

  # Backend type
  backend_type = "azurerm"

  # Azure Blob Storage backend configuration
  backend_config = {
    resource_group_name  = local.resource_group_name
    storage_account_name = local.storage_account_name
    container_name       = local.storage_container_name
    key                  = "${local.env_name}/${local.location}/${path_relative_to_include()}/terraform.tfstate"
  }

  # Provider block to be generated
  provider_block = <<EOF
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.45.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "${local.subscription_id}"
  tenant_id       = "${local.tenant_id}"
}
EOF

  # Default values for Azure
  defaults = {
    region          = local.location
    location        = local.location
    subscription_id = local.subscription_id
    tenant_id       = local.tenant_id
  }

  # Azure-specific: modules that need local state (bootstrap)
  # These modules have circular dependencies and must use local state
  bootstrap_modules = ["_bootstrap", "network"]

  # Module config key mapping (used by _common patterns)
  module_config_keys = {
    kubernetes    = "aks"
    network       = "vnet"
    storage       = "azure_blob_storage"
    secrets       = "azure_key_vault"
    load_balancer = "app_gw"
    monitoring    = "alerts"
    iam           = "iam_bindings"
    bastion       = "bastion_host"
    helm          = "helm_charts"
    nat           = "nat"
    bootstrap     = "resource_group"
  }
}
