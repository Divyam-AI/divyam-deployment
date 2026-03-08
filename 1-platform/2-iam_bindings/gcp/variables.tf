variable "env_name" {
  description = "Deployment environment name (e.g. dev, prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "router_logs_bucket_name" {
  description = "GCS bucket name for router logs (storage_bucket scope)"
  type        = string
}
