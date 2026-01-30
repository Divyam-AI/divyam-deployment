variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region where resources will be created."
  type        = string
}

variable "ssl_certificate_name" {
  description = "Name of the Google-managed SSL certificate."
  type        = string
}

variable "ssl_certificate_domains" {
  description = "A list of domains to be covered by the Google-managed SSL certificate."
  type        = list(string)
}

variable "enabled" {
  description = "Whether to create the Google-managed SSL certificate."
  type        = bool
  default     = true
}