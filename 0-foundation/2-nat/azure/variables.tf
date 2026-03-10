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

variable "import_mode" {
  description = "Set to true (e.g. TF_VAR_import_mode=1) when running terraform import so the resource blocks exist; leave false for normal runs."
  type        = bool
  default     = false
}
