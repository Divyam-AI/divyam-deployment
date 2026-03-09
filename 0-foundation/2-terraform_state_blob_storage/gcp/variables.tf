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

variable "bucket_name" {
  description = "Name of the GCS bucket for Terraform state (must be globally unique)"
  type        = string
}

variable "import_mode" {
  description = "Set to true (e.g. TF_VAR_import_mode=1) when running terraform import so the resource block exists; leave false for normal runs."
  type        = bool
  default     = false
}
