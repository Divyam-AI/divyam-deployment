

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region where resources will be created."
  type        = string
  default     = "asia-south1"
}

variable "retention_days" {
  description = "Number of days to retain logs in the _Default bucket"
  type        = number
  default     = 30
}