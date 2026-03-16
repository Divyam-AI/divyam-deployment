variable "project_id" {
  description = "GCP project ID for Secret Manager"
  type        = string
}

variable "location" {
  description = "GCP region (for labels/context)"
  type        = string
  default     = null
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = null
}

# Single object passed through to common module (built in one place: secrets_input.hcl).
variable "secrets_input" {
  description = "Secrets input for common module (env + all divyam_* values). Passed from Terragrunt."
  type        = any
  sensitive   = true
}

# When false, do not create or update secrets in Secret Manager.
variable "create_secrets" {
  description = "If true, create/update Secret Manager secrets. If false, do not manage secrets."
  type        = bool
  default     = true
}

