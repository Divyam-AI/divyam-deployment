variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "enabled" {
  description = "When false, no alert policies are created."
  type        = bool
  default     = true
}

variable "rules_folder" {
  description = "Path to folder containing neutral alert rule group JSON files (see 2-alerts/common/rules/README.md)"
  type        = string
}

variable "exclude_list" {
  description = "Alert names to skip (matches rules[].alert)."
  type        = list(string)
  default     = []
}

variable "notification_channels" {
  description = "GCP notification channel IDs to attach to alert policies."
  type        = list(string)
  default     = []
}
