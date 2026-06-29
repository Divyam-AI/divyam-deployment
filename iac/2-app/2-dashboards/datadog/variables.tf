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

variable "cluster_name" {
  description = "Target kube_cluster_name used to re-scope exported (prod) dashboards. Replaces the baked-in divyam-prod-k8s-cluster. From the root config (same source as 2-alerts)."
  type        = string
}

variable "env" {
  description = "Deployment env name (e.g. sandbox, preprod, prod). Re-scopes the baked-in `prod` env token in dashboard namespace tags (-prod- -> -<env>-) and metric-name prefixes (_prod_/_prod. -> _<env>_/_<env>.). On prod this is a no-op. From the root config."
  type        = string
}
