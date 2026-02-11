variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "apis" {
  type        = list(string)
  description = "List of APIs to enable"
  default     = []
}

variable "enabled" {
  type        = bool
  description = "Flag to enabling APIs"
  default     = false
}