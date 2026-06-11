variable "enabled" {
  description = "When false, no Datadog dashboards are created."
  type        = bool
  default     = true
}

variable "dashboards_folder" {
  description = "Path to folder containing native Datadog dashboard JSON files (exported from the Datadog API/UI)."
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
