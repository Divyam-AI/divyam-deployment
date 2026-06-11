# Inputs for the shared alert renderer. This module has no providers and creates no
# resources — it only computes rendered query strings + expanded rule objects that the
# per-backend modules (gcp/alerts, azure, datadog) map onto their resources.

variable "rules_folder" {
  description = "Path to the folder of neutral rule-group JSON files (see ../rules/README.md). The file named metric_map.json is excluded from the rule groups."
  type        = string
}

variable "metric_map_file" {
  description = "Path to the central metric catalog (generic name -> {prometheus, datadog})."
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name substituted for {{cluster_name}} and injected as the Datadog kube_cluster_name scope."
  type        = string
  default     = ""
}

variable "env" {
  description = "Deployment environment name substituted for {{env}} (e.g. in env-suffixed namespaces like eval-{{env}}-ns)."
  type        = string
  default     = ""
}

variable "exclude_list" {
  description = "Alert names to skip (matches rules[].alert)."
  type        = list(string)
  default     = []
}

variable "default_window" {
  description = "Default Datadog look-back window when a rule omits `window` (Go-duration shorthand, e.g. 15m)."
  type        = string
  default     = "15m"
}
