variable "project_id" {
  type        = string
  description = "The GCP project ID where the Shared VPC will be created. This must be the host project."
}

variable "region" {
  type        = string
  description = "The GCP region where the subnet will be created."
}

variable "network_name" {
  type        = string
  description = "Name of the Shared VPC network to create in the host project."
}

variable "subnets" {
  type = list(object({
    subnet_name       = string
    subnet_ip         = string
    region            = string
    secondary_ranges  = optional(list(object({ 
      range_name    = string
      ip_cidr_range = string
      reserved_internal_range = optional(string)
    })), [])
  }))
  description = "List of subnets with optional secondary ranges. Secondary Ranges are Useful for GKE pods and services or alias IP configurations."
}