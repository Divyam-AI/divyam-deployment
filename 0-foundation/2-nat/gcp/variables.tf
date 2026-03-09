variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region where resources will be created."
  type        = string
}

variable "network" {
  description = "The VPC network name to use."
  type        = string
}

variable "router_name" {
  description = "Name of the Cloud Router."
  type        = string
}

variable "nat_config_name" {
  description = "Name of the NAT configuration."
  type        = string
}

variable "nat_subnetworks" {
  type = list(object({
    name  = string
    cidrs = list(string)
  }))
  description = "List of subnetwork NAT configurations (name = self link, cidrs = IP ranges to NAT)."
}

variable "enabled" {
  description = "Whether to create the NAT configuration."
  type        = bool
  default     = true
}

variable "import_mode" {
  description = "Set to true (e.g. TF_VAR_import_mode=1) when running terraform import so the resource blocks exist; leave false for normal runs."
  type        = bool
  default     = false
}
