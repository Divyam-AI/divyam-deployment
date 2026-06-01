variable "enabled" {
  type    = bool
  default = true
}

variable "project_id" {
  type = string
}

variable "region" {
  description = "GKE cluster region (same as 1-k8s/gcp)."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name from values k8s.name (or monitoring.native.gmp_cluster_name override)."
  type        = string
  default     = null
}

variable "enable_workload_logs" {
  type    = bool
  default = true
}

variable "enable_cluster_logs" {
  type    = bool
  default = true
}

variable "enable_managed_prometheus" {
  type    = bool
  default = false
}

variable "logs_retention_days" {
  type    = number
  default = 30
}

variable "manage_project_log_bucket" {
  type    = bool
  default = true
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
