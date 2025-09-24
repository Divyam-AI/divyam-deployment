variable "location" {
  description = "Azure provider location"
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

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "clusters" {
  description = "A map of AKS cluster configurations. The key is the cluster name."
  type = map(object({
    kubernetes_version              = string
    api_server_authorized_ip_ranges = optional(list(string), null)
    private_cluster_enabled         = optional(bool, true)
    vnet_subnet_name                = string

    network_plugin = optional(string, "azure") # e.g. "azure" or "kubenet"
    network_policy = optional(string, "azure") # e.g. "azure"
    dns_service_ip = string
    service_cidr   = string
    dns_prefix     = string

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
      vm_size      = string
      gpu_driver   = optional(string, "Install")
      auto_scaling = bool
      count        = optional(number, null)
      min_count    = optional(number, null)
      max_count    = optional(number, null)
      mode         = optional(string, "User")
      node_taints  = optional(list(string), [])
      tags         = optional(map(string), {})
      node_labels  = optional(map(string), {})
    })), {})
  }))
}

variable "vnet_id" {
  description = "ID of the Virtual Network"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet resource IDs"
  type        = map(string)
}

variable "subnet_names" {
  description = "List of subnet names"
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "Map of subnet CIDR prefixes"
  type        = map(string)
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway for AGIC integration"
  type        = string
}

variable "app_gateway_id" {
  description = "ID of the Application Gateway for AGIC integration"
  type        = string
}

variable "nat_gateway_ip" {
  description = "IP of the NAT Gateway"
  type        = string
}

variable "agic_identity_id" {
  description = "ID of the AGIC managed identity"
  type        = string
}

variable "agic_client_id" {
  description = "Client ID of the AGIC managed identity"
  type        = string
}

variable "enable_log_collection" {
  description = "Enables container log collection to Azure log analytics workspace."
  type        = bool
  default     = true
}

variable "enable_metrics_collection" {
  description = "Enables managed prometheus metrics collection"
  type        = bool
  default     = true
}

variable "exclude_charts" {
  description = "Optional list of charts to exclude"
  type        = list(string)
  default     = []
}

variable "artifacts_path" {
  description = "Path to artifacts.yaml file"
  type        = string
}
