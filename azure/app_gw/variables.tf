variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
}

variable "backend_service_name" {
  description = "The base name for the backend service and associated resources (App Gateway, IPs, etc)."
  type        = string
}

variable "create_public_lb" {
  description = "Whether to create a public-facing Application Gateway (true) or internal (false)."
  type        = bool
}

variable "location" {
  description = "Azure region where the resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to deploy the Application Gateway and related resources."
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Vnet resource group"
  type = string
}

variable "subnet_ids" {
  description = "Map of subnet resource IDs"
  type        = map(string)
}

variable "vnet_subnet_name" {
  description = "The name of the subnet to use"
  type        = string
}

variable "certificate_secret_id" {
  description = "Optional TLS certificate id"
  type        = string
  default     = null
}

variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
}

variable "tls_enabled" {
  description = "Indicates if TLS is enabled"
  type        = bool
}
