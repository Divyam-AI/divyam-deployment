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

variable "cluster_name" {
  description = "AKS cluster name from values k8s.name; used to derive the Azure Monitor workspace name when azure_monitor_workspace_name is null."
  type        = string
}

variable "azure_monitor_workspace_name" {
  description = "Optional override for the Azure Monitor workspace name (monitoring.native.azure_monitor_workspace_name)."
  type        = string
  default     = null
}

variable "rules_folder" {
  description = "Path to folder containing neutral alert rule group JSON files (see 3-alerts/common/rules/README.md)"
  type        = string
}

variable "webhook_urls" {
  description = "List of pager / Zenduty-style webhook URLs to notify on CRITICAL alerts."
  type        = list(string)
  default     = []
}

variable "resource_name_prefix" {
  description = "Resource name prefix to use"
  type        = string
}
