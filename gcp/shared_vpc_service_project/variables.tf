variable "host_project_id" {
  type        = string
  description = "The project ID of the Shared VPC host project."
}

variable "service_project_id" {
  type        = string
  description = "The project ID of the service project that should attach to the host Shared VPC."
}