variable "vnet" {
  description = "Configuration for VPC (GCP) and its subnets. Single subnet and single app_gw_subnet (source of truth: values/defaults.hcl). GCP: optional Shared VPC host and service project attachments."

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

    # GCP Shared VPC: when true, enable scope_name (host project) as Shared VPC host.
    shared_vpc_host = optional(bool, false)
    # GCP: project IDs to attach as service projects to this Shared VPC (requires shared_vpc_host = true and vnet.create = true).
    service_project_ids = optional(list(string), [])
  })
}
