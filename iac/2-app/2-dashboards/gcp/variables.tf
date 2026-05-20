variable "enabled" {
  description = "When false, no GCP dashboards are created."
  type        = bool
  default     = true
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "dashboards_folder" {
  description = "Path to folder containing GCM-native dashboard JSON files."
  type        = string
}
