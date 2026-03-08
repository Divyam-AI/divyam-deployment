variable "vnet" {
  description = "Configuration for Virtual Network (Azure VNet) and its sub-resources. Single subnet and single app_gw_subnet. Optional: Shared VPC-style hub with peering to remote VNets."

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

    # When true, treat this VNet as hub and peer to remote VNets listed in service_project_ids (remote VNet ARM IDs).
    shared_vpc_host = optional(bool, false)
    # Remote VNet IDs to peer with (full ARM IDs, e.g. /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/...). Requires shared_vpc_host = true and vnet.create = true.
    service_project_ids = optional(list(string), [])
  })
}