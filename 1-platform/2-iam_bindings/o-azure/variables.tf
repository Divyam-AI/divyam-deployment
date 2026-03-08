variable "env_name" {
  description = "Deployment environment name (e.g. dev, prod)"
  type        = string
}

variable "resource_group_name" {
  type        = string
  description = "Azure resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "environment" {
  description = "Deployment environment (alias for tagging)"
  type        = string
}

variable "aks_cluster_name" {
  description = "The AKS cluster name"
  type        = string
}

variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
}

variable "router_logs_storage_account_id" {
  description = "The Router logs storage account id"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "The AKS cluster OIDC issuer URL"
  type        = string
}
