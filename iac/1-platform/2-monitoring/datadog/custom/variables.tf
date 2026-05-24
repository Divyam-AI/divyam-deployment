variable "kubeconfig_path" {
  description = "Path to kubeconfig for the custom cluster (usually from KUBECONFIG on the apply host)."
  type        = string
}

variable "cluster_name" {
  description = "Datadog global.clusterName tag (must match 2-alerts datadog queries {{cluster_name}})."
  type        = string
}

variable "datadog_enabled" {
  type    = bool
  default = false
}

variable "datadog_site" {
  type = string
}

variable "datadog_env" {
  type = string
}

variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_docker_registry" {
  type    = string
  default = "asia.gcr.io/datadoghq"
}

variable "datadog_exclude_namespaces" {
  type    = list(string)
  default = []
}

variable "datadog_exclude_namespaces_logs" {
  type    = list(string)
  default = []
}

variable "datadog_exclude_namespaces_metrics" {
  type    = list(string)
  default = []
}

variable "divyam_clickhouse_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "divyam_db_password" {
  type      = string
  default   = ""
  sensitive = true
}
