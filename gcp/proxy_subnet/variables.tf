variable "project_id" {
  description = "The ID of the Google Cloud project."
  type        = string
}

variable "region" {
  description = "The region where the proxy-only subnet will be created."
  type        = string
}

variable "network_self_link" {
  description = "The self_link of the network to which the subnet will be attached."
  type        = string
}

variable "subnet_name" {
  description = "The name of the proxy-only subnet."
  type        = string
  default     = "gke-proxy-subnet"
}

variable "ip_cidr_range" {
  description = "The primary IP CIDR range for the proxy-only subnet."
  type        = string
}