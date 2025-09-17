variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aks_cluster_name" {
  description = "AKS  Cluster name"
  type        = string
}

variable "aks_kube_config" {
  description = "Map of AKS cluster names and their kube configs"
  type        = map(map(string))
}

variable "azure_workload_identity_version" {
  description = "Version of  Azure Workload Identity chart"
  type        = string
  default     = "1.1.0"
}

variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
}

variable "azure_key_vault_uri" {
  description = "The Azure Key Vault ID"
  type        = string
}

variable "divyam_docker_registry_url" {
  description = "URL of registry containing divyam docker images"
  type        = string
}

variable "divyam_helm_registry_url" {
  description = "URL of registry containing divyam helm charts"
  type        = string
}

variable "artifacts_path" {
  description = "Path to artifacts.yaml file"
  type        = string
}

variable "values_dir_path" {
  description = "Path to values file for the heml charts"
  type        = string
}

variable "helm_release_replace_all" {
  description = "Replace all existing charts as a last resort when charts are stuck due to state corruption or other errors."
  type        = bool
  default     = false
}

variable "helm_release_recreate_pods_all" {
  description = "Perform pods restart during upgrade/rollback"
  type        = bool
  default     = false
}

variable "helm_release_force_update_all" {
  description = "Force resource update through delete/recreate if needed"
  type        = bool
  default     = false
}

variable "exclude_charts" {
  description = "Optional list of charts to exclude"
  type        = list(string)
  default     = []
}

# Access control UAI client IDs.
variable "uai_client_ids" {
  description = "A map from name to UAI client name to client IDs"
  type        = map(string)
}

variable "azure_router_logs_storage_connection_string" {
  description = "Azure Blob Storage connection string"
  type        = string
}

variable "azure_router_logs_storage_account_name" {
  description = "The name of the Azure Storage Account."
  type        = string
}

variable "azure_router_logs_container_name" {
  description = "Azure Blob Storage container name"
  type        = string
}

variable "router_dns_zone" {
  description = "The router DNS zone."
  type        = string
  default     = null
}

variable "dashboard_dns_zone" {
  description = "The dashboard DNS zone."
  type        = string
  default     = null
}

variable "app_gateway_tls_enabled" {
  description = "Indicates if TLS is enabled at the Application Gateway."
  type        = bool
}

variable "app_gateway_certificate_secret_id" {
  description = "Application Gateway certificate secret id."
  type        = string
}
