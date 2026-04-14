variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name for Datadog global.clusterName."
  type        = string
}

variable "cluster_endpoint" {
  description = "GKE control plane endpoint without https scheme."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "GKE cluster CA certificate (base64 encoded)."
  type        = string
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
