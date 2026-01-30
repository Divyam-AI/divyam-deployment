variable "project_id" {
  description = "The GCP project ID in which to create the global address. If not provided, the provider's default project is used."
  type        = string
}

variable "region" {
  type = string
}

variable "address_name" {
  description = "The name of the global static address to create."
  type        = string
}

variable "dashboard_address_name" {
  description = "The name of the global static address to create for usage dashboard."
  type        = string
}

variable "test_address_name" {
  description = "The name of the test global static address to create."
  type        = string
}

variable "enabled" {
  description = "Whether to create the static address."
  type        = bool
  default     = true
}
