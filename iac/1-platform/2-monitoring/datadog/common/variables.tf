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

# --- Cloud-specific (only one set is used per Terragrunt unit: azure / gcp / custom) ---

variable "kube_config" {
  description = "AKS kubeconfig from 1-k8s/azure outputs (Azure unit only)."
  type = object({
    host                   = string
    client_certificate     = string
    client_key             = string
    cluster_ca_certificate = string
  })
  default   = null
  sensitive = true
}

variable "project_id" {
  description = "GCP project ID (GCP unit only)."
  type        = string
  default     = null
}

variable "region" {
  description = "GCP region (GCP unit only)."
  type        = string
  default     = null
}

variable "cluster_endpoint" {
  description = "GKE control plane endpoint without https:// scheme (GCP unit only)."
  type        = string
  default     = null
}

variable "cluster_ca_certificate" {
  description = "GKE cluster CA certificate, base64-encoded (GCP unit only)."
  type        = string
  default     = null
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig on the apply host (custom K8s unit only)."
  type        = string
  default     = null
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com)."
  type        = string
  default     = ""

  validation {
    condition     = !var.datadog_enabled || trimspace(var.datadog_site) != ""
    error_message = "When datadog.enabled is true, datadog.site must be set in the values file."
  }
}

variable "datadog_env" {
  description = "Datadog environment tag (env:...)."
  type        = string
  default     = ""

  validation {
    condition     = !var.datadog_enabled || trimspace(var.datadog_env) != ""
    error_message = "When datadog.enabled is true, datadog.env must be set in the values file."
  }
}

variable "datadog_api_key" {
  description = "Datadog API key."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.datadog_enabled || trimspace(var.datadog_api_key) != ""
    error_message = "When datadog.enabled is true, export TF_VAR_datadog_api_key."
  }
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

variable "clickhouse_host" {
  description = "In-cluster FQDN of the ClickHouse HTTP service the Datadog check connects to. Default matches the Altinity CHI (release clk-dev) deployed by the clickhouse Helm chart."
  type        = string
  default     = "clickhouse-clk-dev.clickhouse-dev-ns.svc.cluster.local"
}

variable "clickhouse_port" {
  description = "ClickHouse HTTP port for the Datadog check (clickhouse-connect uses HTTP, not the 9000 native TCP port)."
  type        = number
  default     = 8123
}

variable "clickhouse_username" {
  description = "ClickHouse user for the Datadog check; pairs with divyam_clickhouse_password. Matches divyam_clickhouse_user_name (default \"default\")."
  type        = string
  default     = "default"
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

