variable "enabled" {
  description = "When false, no Grafana dashboards are created."
  type        = bool
  default     = true
}

variable "dashboards_folder" {
  description = "Path to folder containing Grafana dashboard JSON files."
  type        = string
}

variable "grafana_endpoint" {
  description = "Azure Managed Grafana endpoint URL (e.g. https://<name>-<suffix>.<region>.grafana.azure.com)."
  type        = string
}

variable "grafana_api_token" {
  description = "Grafana service-account API token. Pass via TF_VAR_grafana_api_token."
  type        = string
  sensitive   = true
}
