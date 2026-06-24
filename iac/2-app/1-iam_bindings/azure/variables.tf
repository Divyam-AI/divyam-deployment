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
  description = "The AKS cluster name (from defaults.hcl k8s.name). Looked up in Azure to get OIDC issuer URL."
  type        = string
  default     = null
}

variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
}

# Router logs storage: pass name from defaults.hcl (divyam_object_storages type = \"router-requests-logs\") and it is looked up in Azure; or pass id for backward compatibility.
variable "router_logs_storage_account_name" {
  description = "Azure storage account name for router-requests-logs (from defaults.hcl). Looked up in Azure to get storage account ID. Optional if router_logs_storage_account_id is set."
  type        = string
  default     = null
}

variable "router_logs_storage_account_id" {
  description = "The Router logs storage account ID. Optional when router_logs_storage_account_name is set (looked up in Azure)."
  type        = string
  default     = null
}

variable "stack" {
  description = "Divyam stack selector (evalm8, router, both). Gates the evalm8 service accounts in the common registry."
  type        = string
  default     = "both"
}

variable "evalm8_lakefs_storage_account_name" {
  description = "Azure storage account name for the evalm8 lakeFS store (from the object_storage unit). Looked up in Azure to get the storage account ID. Optional."
  type        = string
  default     = null
}

variable "evalm8_lakefs_storage_account_id" {
  description = "The evalm8 lakeFS storage account ID. Optional when evalm8_lakefs_storage_account_name is set (looked up in Azure)."
  type        = string
  default     = null
}
