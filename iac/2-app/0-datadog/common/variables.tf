# Cloud-agnostic Datadog Operator + DatadogAgent install. Invoked from Azure/GCP roots after
# those stacks configure kubernetes/helm providers (cert auth vs GCP token).

variable "datadog_enabled" {
  description = "When true, install Datadog Operator and DatadogAgent."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Kubernetes cluster name for Datadog global.clusterName."
  type        = string
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com)."
  type        = string
  default     = ""
}

variable "datadog_env" {
  description = "Datadog environment tag (env:...)."
  type        = string
  default     = ""
}

variable "datadog_api_key" {
  description = "Datadog API key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "divyam_clickhouse_password" {
  description = "ClickHouse default user password from TF_VAR_divyam_clickhouse_password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "divyam_db_password" {
  description = "Divyam application MySQL user password (same as used for the datadog@ MySQL user); from TF_VAR_divyam_db_password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_docker_registry" {
  description = "Container registry for Datadog images (global.registry on DatadogAgent)."
  type        = string
  default     = "asia.gcr.io/datadoghq"
}

variable "datadog_exclude_namespaces" {
  description = "Shared namespaces excluded from both logs and metrics."
  type        = list(string)
  default     = []
}

variable "datadog_exclude_namespaces_logs" {
  description = "Additional log-only exclusions (concatenated after shared list, deduplicated)."
  type        = list(string)
  default     = []
}

variable "datadog_exclude_namespaces_metrics" {
  description = "Additional metrics-only exclusions (concatenated after shared list, deduplicated)."
  type        = list(string)
  default     = []
}

