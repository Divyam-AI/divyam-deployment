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
  description = "GCS bucket name for router logs (from defaults.hcl divyam_object_storages type = \"router-requests-logs\" container_name). Optional; when null, storage_bucket IAM bindings are skipped."
  type        = string
  default     = null
}

variable "stack" {
  description = "Divyam stack selector (evalm8, router, both). Gates the evalm8 service accounts in the common registry."
  type        = string
  default     = "both"
}

variable "evalm8_lakefs_bucket_name" {
  description = "GCS bucket name for the evalm8 lakeFS store (from the object_storage unit). Optional, when null the lakefs_bucket IAM bindings are skipped."
  type        = string
  default     = null
}
