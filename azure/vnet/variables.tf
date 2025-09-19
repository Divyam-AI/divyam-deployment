variable "resource_group_name" {
  type        = string
  description = "Azure resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "use_existing_vnet" {
  description = "The name of the existing Azure VNet to use"
  type        = bool
  default     = false
}

variable "network_name" {
  type        = string
  description = "VNet name"
  # Leave null if existing vnet is used.
  default = null
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the VNet"
  # Leave empty if existing vnet is used.
  default = []
}

variable "subnets" {
  description = "List of subnets with IPs and names"
  type = list(object({
    subnet_name  = string
    subnet_ip    = optional(string, null)
    use_existing = optional(bool, false)
  }))
  # Leave empty if existing vnet is used.
  default = []
}
