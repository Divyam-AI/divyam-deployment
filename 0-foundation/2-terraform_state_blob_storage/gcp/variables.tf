variable "project_id" {
  description = "GCP project ID for the state bucket"
  type        = string
}

variable "location" {
  description = "GCP location (region or multi-region) for the bucket"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "create" {
  description = "Whether to create the GCS bucket (false = use existing)"
  type        = bool
}

variable "local_state" {
  description = "When true, do not create or lookup a bucket; state is stored locally only."
  type        = bool
  default     = false
}

variable "bucket_name" {
  description = "Name of the GCS bucket for Terraform state (must be globally unique)"
  type        = string
}

