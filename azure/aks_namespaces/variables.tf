variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
}

variable "aks_cluster_name" {
  description = "AKS  Cluster name"
  type        = string
}

variable "aks_kube_config" {
  description = "Map of AKS cluster names and their kube configs"
  type        = map(map(string))
}

variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
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

variable "divyam_docker_registry_url" {
  description = "URL of registry containing divyam helm charts"
  type        = string
}