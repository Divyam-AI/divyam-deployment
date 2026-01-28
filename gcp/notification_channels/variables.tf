
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "region" {
  description = "GCP Region (e.g., us-central1)"
  type        = string
}
variable "pager_enabled" {
  description = "Create notification channel for pager"
  type        = bool
  default     = false
}

variable "pager_webhook_url" {
  description = "Webhook URL for receiving alerts"
  type        = string
}

variable "gchat_enabled" {
  description = "Create notification channel for google chat"
  type        = bool
  default     = false
}

variable "gchat_space_id" {
  description = "Google Chat space ID for receiving alerts"
  type        = string
}

variable "email_enabled" {
  description = "Create notification channel for email"
  type        = bool
  default     = false
}

variable "email_alert_email" {
  description = "Email address for receiving alerts"
  type        = string
}