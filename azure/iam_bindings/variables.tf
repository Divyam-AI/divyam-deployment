variable "resource_group_name" {
  type        = string
  description = "Azure resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "environment" {
  description = "Deployment environment"
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

variable "aks_oidc_issuer_urls" {
  description = "The AKS cluster oidc issuer urls"
  type        = map(string)
}

variable "artifacts_path" {
  description = "Path to artifacts.yaml file"
  type        = string
}

variable "exclude_charts" {
  description = "Optional list of charts to exclude"
  type        = list(string)
  default     = []
}