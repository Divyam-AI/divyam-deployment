variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "resource_name_prefix" {
  description = "Resource group to use"
  type        = string
}

variable "create" {
  description = "Indicates if the nat gateway needs creation"
  type        = bool
}

variable "subnet_ids" {
  description = "Map of subnet resource IDs"
  type        = map(string)
}

variable "vnet_subnet_name" {
  description = "Name of the subnet to generate NAT gateway for"
  type        = string
}