variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "project_id" {
  description = "GCP project ID (used as secretsProjectId in env.yaml)."
  type        = string
}

variable "storage_bucket" {
  description = "GCS bucket name for platform storage_configs."
  type        = string
  default     = ""
}

variable "cluster_domain" {
  description = "Cluster domain for cross-cluster DNS. Leave empty for in-cluster."
  type        = string
  default     = ""
}

variable "image_pull_secret_enabled" {
  description = "Whether the cluster needs image pull secrets for a private registry."
  type        = bool
  default     = false
}

variable "output_path" {
  description = "Absolute path for the generated env.yaml file."
  type        = string
}
