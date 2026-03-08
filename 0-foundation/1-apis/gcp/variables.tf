variable "project_id" {
  type        = string
  description = "GCP Project ID (from resource scope)"
}

variable "apis" {
  type        = list(string)
  description = "List of GCP API service names to enable (e.g. compute.googleapis.com)"
  default     = []
}

variable "enabled" {
  type        = bool
  description = "Whether to enable the listed APIs"
  default     = true
}
