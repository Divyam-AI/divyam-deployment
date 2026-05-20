variable "enabled" {
  description = "When false, no Datadog monitors are created."
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

variable "env" {
  description = "Environment tag injected into Datadog monitor tags."
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name injected into Datadog monitor tags."
  type        = string
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com, datadoghq.eu, ap1.datadoghq.com)."
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key. Pass via TF_VAR_datadog_api_key."
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key. Pass via TF_VAR_datadog_app_key."
  type        = string
  sensitive   = true
}

variable "webhook_urls" {
  description = "List of pager / Zenduty-style webhook URLs. Each is registered as a Datadog webhook integration and referenced as @webhook-<name> on CRITICAL monitor messages."
  type        = list(string)
  default     = []
}

variable "webhook_name_prefix" {
  description = "Prefix for the generated Datadog webhook integration names; the final name is `<prefix>-<idx>`."
  type        = string
  default     = "divyam-pager"
}
