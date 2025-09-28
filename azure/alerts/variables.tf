variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
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

variable "azure_monitor_workspace_name" {
  description = "Name of the azure monitor workspace"
  type        = string
}

variable "azure_monitor_workspace_id" {
  description = "ID of the azure monitor workspace"
  type        = string
}

variable "alerts_folder" {
  default = "./alerts"
}

variable "notification_pager_webhook_url" {
  type        = string
  default     = null
  description = "PagerDuty/Zenduty webhook endpoint"
}

variable "notification_gchat_space_id" {
  type        = string
  default     = null
  description = "Google Chat Space ID for webhook"
}

variable "notification_email_alert_email" {
  type        = string
  default     = null
  description = "Email address for alerts"
}

# TODO: Move to common and take once.
variable "resource_name_prefix" {
  description = "Resource name prefix to use"
  type        = string
  default     = "divyam"
}