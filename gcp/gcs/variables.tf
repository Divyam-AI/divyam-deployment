variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region where the bucket will be created"
  type        = string
  default     = "us-central1"
}

variable "raw_router_logs_bucket_name" {
  description = "The name of the raw_router_logs GCS bucket"
  type        = string
}

variable "force_destroy" {
  description = "Whether to allow bucket deletion even if it contains objects"
  type        = bool
  default     = false
}