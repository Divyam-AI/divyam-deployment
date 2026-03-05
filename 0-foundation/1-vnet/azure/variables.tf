variable "vnet" {
  description = "Configuration for Virtual Network (Azure VNet or GCP VPC) and its sub-resources."

  type = object({

    # Whether the VNet/VPC should be created by this module.
    # If false, the module assumes the network already exists.
    create = bool

    # Name of the VNet (Azure) or VPC (GCP).
    name = string

    # Scope where the network exists or will be created.
    # Azure: Resource Group name
    # GCP: Project ID
    scope_name = string

    # Region where the network resources will be deployed.
    region = string

    # Availability zone used by resources that require zone-level placement.
    # Not all resources use this value.
    zone = string

    # CIDR ranges assigned to the VNet/VPC.
    # Azure: address_space
    # GCP: primary VPC CIDR range.
    # Leave empty if using an existing network.
    address_space = optional(list(string), [])

    # List of subnet definitions within the VNet/VPC.
    subnets = optional(list(object({

      # Name of the subnet.
      subnet_name = string

      # CIDR block assigned to the subnet.
      # Optional if the subnet already exists.
      subnet_ip = optional(string, null)

      # If true, the module creates the subnet; if false, looks up an existing subnet.
      create = optional(bool, true)

    })), [])

    # Application Gateway related configuration.
    # required to attach an Application Gateway to the VNet.
    app_gw_subnet = optional(list(object({

      # Name of the subnet.
      subnet_name = string

      # CIDR block assigned to the subnet.
      # Optional if the subnet already exists.
      subnet_ip = optional(string, null)

      # If true, the module creates the subnet; if false, looks up an existing subnet.
      create = optional(bool, true)

    })), [])

  })
}