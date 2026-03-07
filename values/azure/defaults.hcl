#----------------------------------------------
# Azure-specific deployment values.
# Merged with values/defaults.hcl. Region/zone come from common (REGION, ZONE env).
# Set via env: ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
#----------------------------------------------
locals {

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

  # AKS cluster defaults; merged with values/defaults.hcl k8s (create, name).
  # vnet_subnet_name is set in terragrunt from vnet.subnets[0].subnet_name.
  k8s_aks = {
    dns_prefix                = null # default: use k8s.name in terragrunt
    kubernetes_version        = "1.28"
    private_cluster_enabled   = true
    api_server_authorized_ip_ranges = []
    network_plugin            = "azure"
    network_policy            = "azure"
    dns_service_ip            = "10.1.0.10"
    service_cidr              = "10.1.0.0/16"
    default_node_pool = {
      vm_size      = "Standard_D4s_v3"
      auto_scaling = true
      min_count    = 1
      max_count    = 5
      count        = null
      tags         = {}
      node_labels  = {}
      temporary_name_for_rotation = "tempnp01"
    }
    additional_node_pools = {}
    enable_log_collection    = true
    enable_metrics_collection = true
    agic_helm_version        = "1.7.0"
  }
}