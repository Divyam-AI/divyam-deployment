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
  description = "Path to folder containing neutral alert rule group JSON files (see 3-alerts/common/rules/README.md)"
  type        = string
}

variable "metric_map_file" {
  description = "Path to the central metric catalog consumed by the render module (generic name -> {prometheus, datadog})."
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name substituted for {{cluster_name}} in rules (and the Datadog scope, unused here). Default empty."
  type        = string
  default     = ""
}

variable "env" {
  description = "Deployment environment name substituted for {{env}} in rules (e.g. env-suffixed namespaces). Default empty."
  type        = string
  default     = ""
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
