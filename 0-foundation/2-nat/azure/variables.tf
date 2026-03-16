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

variable "subnet_ids" {
  description = "Map of subnet resource IDs to associate with the NAT gateway"
  type        = map(string)
}

