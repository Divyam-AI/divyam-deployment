variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet resource IDs"
  type        = map(string)
}

variable "vnet_subnet_name" {
  description = "Name of the subnet to generate NAT gateway for"
  type        = string
}