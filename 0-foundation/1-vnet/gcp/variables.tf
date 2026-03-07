variable "vnet" {
  description = "Configuration for VPC (GCP) and its subnets. Single subnet and single app_gw_subnet (source of truth: values/defaults.hcl)."

  type = object({

    create     = bool
    name       = string
    scope_name = string
    region     = string
    zone       = string

    address_space = optional(list(string), [])

    subnet = object({
      name      = string
      subnet_ip = optional(string, null)
      create    = optional(bool, true)
    })

    app_gw_subnet = object({
      name      = string
      subnet_ip = optional(string, null)
      create    = optional(bool, true)
    })
  })
}
