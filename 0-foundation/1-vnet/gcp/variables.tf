variable "vnet" {
  description = "Configuration for VPC (GCP equivalent of Azure VNet) and its subnets. app_gw_subnet is ignored on GCP."

  type = object({

    create     = bool
    name       = string
    scope_name = string
    region     = string
    zone       = string

    address_space = optional(list(string), [])

    subnets = optional(list(object({
      subnet_name = string
      subnet_ip   = optional(string, null)
      create      = optional(bool, true)
    })), [])

    # App Gateway subnets are Azure-only; ignored for GCP. Optional for variable compatibility.
    app_gw_subnet = optional(list(object({
      subnet_name = string
      subnet_ip   = optional(string, null)
      create      = optional(bool, true)
    })), [])

  })
}
