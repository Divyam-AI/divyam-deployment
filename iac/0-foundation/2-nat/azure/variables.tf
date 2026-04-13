variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "resource_name_prefix" {
  description = "Resource name prefix to use"
  type        = string
  default     = "divyam"
}

variable "create" {
  description = "Whether to create the NAT gateway and associations"
  type        = bool
}

variable "lookup_resource_group_name" {
  description = "Resource group to use for data-source lookup when create = false. Defaults to resource_group_name when null."
  type        = string
  default     = null
}

variable "nat_gateway_name" {
  description = "Name of the existing NAT gateway to look up when create = false. Ignored when create = true (prefix-derived name is used)."
  type        = string
  default     = null
}

variable "nat_public_ip_name" {
  description = "Name of the existing public IP to look up when create = false. Ignored when create = true (prefix-derived name is used)."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Map of subnet resource IDs to associate with the NAT gateway"
  type        = map(string)
}

