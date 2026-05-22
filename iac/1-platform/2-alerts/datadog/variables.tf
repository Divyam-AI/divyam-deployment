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
  description = "Environment tag on Datadog monitors (e.g. prod). Should match deployment env_name, not the Datadog Agent env tag."
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

variable "webhook_custom_payload_enabled" {
  description = "When true, sets encode_as=json and payload on each datadog_webhook (Zenduty-friendly default unless webhook_custom_payload is set)."
  type        = bool
  default     = true
}

variable "webhook_custom_payload" {
  description = <<-EOT
    Optional map/object for the Datadog webhook custom JSON payload. Values may use Datadog template variables
    (e.g. $ALERT_ID, $EVENT_TITLE). When null and webhook_custom_payload_enabled is true, a built-in Zenduty-style
    default payload is applied. When webhook_custom_payload_enabled is false, payload is not set (Datadog UI default).
  EOT
  type        = any
  default     = null
}

variable "notify_no_data" {
  description = "When true, notify when a monitor stops receiving metrics (detects integration gaps)."
  type        = bool
  default     = true
}

variable "no_data_timeframe" {
  description = "Minutes without data before no-data notification (only when notify_no_data = true)."
  type        = number
  default     = 15
}

variable "renotify_interval" {
  description = "Minutes between re-notifications for CRITICAL and WARNING monitors while still in alert/warn state."
  type        = number
  default     = 30
}

variable "renotify_statuses" {
  description = "Alert states that trigger re-notification."
  type        = list(string)
  default     = ["alert", "warn"]
}
