variable "enabled" {
  description = "When false, no Grafana dashboards are created."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Azure resource group containing the Managed Grafana instance."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name from values k8s.name; used to derive Managed Grafana name when grafana_endpoint_override is null."
  type        = string
}

variable "grafana_endpoint_override" {
  description = "Optional Managed Grafana endpoint URL (monitoring.native.grafana_endpoint). When set, skips data lookup."
  type        = string
  default     = null
}

variable "dashboards_folder" {
  description = "Path to folder containing Grafana dashboard JSON files."
  type        = string
}

variable "grafana_api_token" {
  description = "Grafana service-account API token. Pass via TF_VAR_grafana_api_token."
  type        = string
  sensitive   = true
}
