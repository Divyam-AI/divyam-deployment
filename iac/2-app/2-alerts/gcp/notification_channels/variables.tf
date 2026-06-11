variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "GCP Region (e.g., us-central1)"
  type        = string
}

variable "webhook_urls" {
  description = "List of pager / Zenduty-style webhook URLs. One notification channel is created per URL."
  type        = list(string)
  default     = []
}
