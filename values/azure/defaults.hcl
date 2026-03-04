#----------------------------------------------
# Azure-specific deployment values.
# Merged with values/defaults.hcl. Region/zone come from common (REGION, ZONE env).
# Set via env: ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
#----------------------------------------------
locals {
  cloud_provider = "azure"

  subscription_id = get_env("ARM_SUBSCRIPTION_ID")
  tenant_id       = get_env("ARM_TENANT_ID")

  # Remote state backend for all modules except 0-resource_scope and 1-terraform_state_blob_storage
  remote_state = {
    backend = "azurerm"
  }

  # Provider block for root terragrunt generate; only loaded when CLOUD_PROVIDER=azure
  provider_block = <<-EOT
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
  subscription_id = "${local.subscription_id}"
  tenant_id       = "${local.tenant_id}"
}
EOT
}