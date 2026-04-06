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

variable "azure_monitor_workspace_name" {
  description = "Name of the Azure Monitor workspace"
  type        = string
}

variable "azure_monitor_workspace_id" {
  description = "ID of the Azure Monitor workspace"
  type        = string
}

variable "alerts_folder" {
  description = "Path to folder containing alert JSON files (Azure Prometheus format)"
  type        = string
}

variable "notification_pager_webhook_url" {
  description = "PagerDuty/Zenduty webhook endpoint"
  type        = string
  default     = null
}

variable "notification_gchat_space_id" {
  description = "Google Chat Space ID for webhook"
  type        = string
  default     = null
}

variable "notification_email_alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = null
}

variable "notification_slack_webhook_url" {
  description = "Slack Incoming Webhook URL for alerts"
  type        = string
  default     = null
}

variable "resource_name_prefix" {
  description = "Resource name prefix to use"
  type        = string
}
