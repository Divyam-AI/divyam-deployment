variable "enabled" {
  description = "When false, skip native Azure monitoring resources."
  type        = bool
  default     = true
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "cluster_name" {
  description = "AKS cluster name (for DCR association naming)."
  type        = string
}

variable "aks_cluster_id" {
  description = "Resource ID of the AKS cluster to associate Prometheus DCR with."
  type        = string
  default     = null
}

variable "enable_metrics_collection" {
  type    = bool
  default = true
}

variable "create_amw" {
  description = "When true, create Azure Monitor workspace + Grafana. When false, use azure_monitor_workspace_name."
  type        = bool
  default     = true
}

variable "azure_monitor_workspace_name" {
  type    = string
  default = null
}

variable "grafana_endpoint_override" {
  description = "Optional Grafana URL when reusing external Grafana (create_amw = false)."
  type        = string
  default     = null
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "tag_globals" {
  type    = map(string)
  default = {}
}

variable "tag_context" {
  type    = map(string)
  default = {}
}
