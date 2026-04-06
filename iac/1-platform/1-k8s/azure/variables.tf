variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "create" {
  description = "When false, do not create cluster; fetch existing by name and output its details."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster" {
  description = "AKS cluster configuration (name, dns_prefix, node pool, network, etc.)."
  type = object({
    name                            = string
    kubernetes_version              = string
    api_server_authorized_ip_ranges  = optional(list(string), [])
    private_cluster_enabled         = optional(bool, true)
    vnet_subnet_name                = string
    dns_prefix                      = string

    # Node Auto-Provisioning (NAP): set to "Auto" for GKE-style managed node provisioning (platform picks VM size from workload needs). "Manual" = traditional explicit node pools.
    node_provisioning_mode          = optional(string, "Manual")

    # AKS automatic upgrade channel: patch|rapid|stable|node-image (equivalent to GKE release_channel).
    automatic_channel_upgrade       = optional(string, "stable")

    network_plugin = optional(string, "azure")
    network_policy = optional(string, "azure")
    dns_service_ip = optional(string)
    service_cidr   = optional(string)

    default_node_pool = object({
      vm_size                     = string
      auto_scaling                = bool
      count                       = optional(number, null)
      min_count                   = optional(number, null)
      max_count                   = optional(number, null)
      mode                        = optional(string, "User")
      tags                        = optional(map(string), {})
      node_labels                 = optional(map(string), {})
      temporary_name_for_rotation = optional(string, "tempnp01")
    })

    additional_node_pools = optional(map(object({
      vm_size          = string
      machine_type     = optional(string)
      gpu_driver       = optional(string, null)
      priority         = optional(string, "Regular") # "Spot" for spot instances; default node pool cannot be Spot on AKS
      auto_scaling     = bool
      count            = optional(number, null)
      min_count        = optional(number, null)
      max_count        = optional(number, null)
      mode             = optional(string, "User")
      node_taints      = optional(list(string), [])
      tags             = optional(map(string), {})
      node_labels      = optional(map(string), {})
      vnet_subnet_name = optional(string, null)
    })), {})
  })
}

variable "vnet_name" {
  description = "Name of the Virtual Network (looked up in Azure from defaults.hcl vnet.name)"
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Resource group where the VNet exists (defaults.hcl vnet.scope_name)"
  type        = string
}

variable "vnet_subnet_names" {
  description = "List of subnet names to look up (node subnet + app gateway subnet from defaults.hcl)"
  type        = list(string)
}

variable "nat_gateway_ip" {
  description = "IP of the NAT Gateway for API server authorized IPs (optional; if null and nat_public_ip_name set, resolved via data source)"
  type        = string
  default     = null
}

variable "nat_public_ip_name" {
  description = "Name of the NAT gateway's public IP resource in Azure (from defaults.hcl nat.nat_public_ip_name); used to look up IP via data source when nat_gateway_ip is null"
  type        = string
  default     = null
}

variable "enable_log_collection" {
  description = "Enable container log collection to Azure Log Analytics"
  type        = bool
  default     = true
}

variable "enable_metrics_collection" {
  description = "Enable managed Prometheus metrics collection"
  type        = bool
  default     = true
}

variable "logs_retention_days" {
  description = "Retention in days for the Log Analytics workspace (AKS logs). Azure max = 730; values above 730 are capped at 730."
  type        = number
  default     = 7
}

variable "artifacts_path" {
  description = "Optional path to artifacts.yaml for helm chart namespaces (log collection)"
  type        = string
  default     = null
}


