variable "cluster_name" {
  description = "AKS cluster name for Datadog global.clusterName."
  type        = string
}

variable "kube_config" {
  description = "AKS kubeconfig object from 1-platform/1-k8s/azure outputs."
  type = object({
    host                   = string
    client_certificate     = string
    client_key             = string
    cluster_ca_certificate = string
  })
  sensitive = true
}

variable "datadog_enabled" {
  description = "When true, install Datadog Operator and DatadogAgent."
  type        = bool
  default     = false
}

variable "datadog_site" {
  description = "Datadog site from defaults.hcl datadog.registry (for example datadoghq.com, datadoghq.eu)."
  type        = string
  default     = ""

  validation {
    condition     = !var.datadog_enabled || trimspace(var.datadog_site) != ""
    error_message = "When datadog.enabled is true, defaults.datadog.registry (Datadog site) must be set."
  }
}

variable "datadog_env" {
  description = "Datadog environment tag from defaults.hcl datadog.env."
  type        = string
  default     = ""

  validation {
    condition     = !var.datadog_enabled || trimspace(var.datadog_env) != ""
    error_message = "When datadog.enabled is true, defaults.datadog.env must be set."
  }
}

variable "datadog_exclude_namespaces" {
  description = "Shared namespaces excluded from both Datadog logs and metrics."
  type        = list(string)
  default     = []
}

variable "datadog_exclude_namespaces_logs" {
  description = "Additional namespaces to exclude from Datadog log collection (appended to shared namespaces)."
  type        = list(string)
  default     = []
}

variable "datadog_exclude_namespaces_metrics" {
  description = "Additional namespaces to exclude from Datadog metrics collection (appended to shared namespaces)."
  type        = list(string)
  default     = []
}

variable "datadog_api_key" {
  description = "Datadog API key from TF_VAR_datadog_api_key."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.datadog_enabled || trimspace(var.datadog_api_key) != ""
    error_message = "When datadog.enabled is true, TF_VAR_datadog_api_key must be exported."
  }
}

variable "divyam_clickhouse_password" {
  description = "ClickHouse default user password from TF_VAR_divyam_clickhouse_password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "divyam_db_password" {
  description = "Divyam MySQL application user password from TF_VAR_divyam_db_password (mirrors datadog-mysql-secret in cluster)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_docker_registry" {
  description = "Datadog docker registry from defaults.hcl datadog.docker_registry."
  type        = string
  default     = "asia.gcr.io/datadoghq"
}
