variable "vnet" {
  description = "Configuration for Virtual Network (Azure VNet) and its sub-resources. Single subnet and single app_gw_subnet."

  type = object({

    create     = bool
    name       = string
    scope_name = string
    region     = string
    zone       = string

    address_space = optional(list(string), [])

    # Single subnet (source of truth: values/defaults.hcl vnet.subnet).
    subnet = object({
      name      = string
      subnet_ip = optional(string, null)
      create    = optional(bool, true)
    })

    # Single App Gateway subnet (source of truth: values/defaults.hcl vnet.app_gw_subnet).
    app_gw_subnet = object({
      name      = string
      subnet_ip = optional(string, null)
      create    = optional(bool, true)
    })
  })
}