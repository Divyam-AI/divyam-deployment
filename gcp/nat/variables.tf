

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region where resources will be created."
  type        = string
  default     = "asia-south1"
}

variable "network" {
  description = "The VPC network name to use."
  type        = string
  default     = "default"
}

variable "router_name" {
  description = "Name of the Cloud Router."
  type        = string
}

variable "nat_config_name" {
  description = "Name of the NAT Configuration."
  type        = string
}

variable "nat_subnetworks" {
  type = list(object({
    name  = string
    cidrs = list(string)
  }))
  description = "List of subnetwork NAT configurations"
}

variable "enabled" {
  description = "Whether to create the NAT configuration."
  type        = bool
  default     = true
}
