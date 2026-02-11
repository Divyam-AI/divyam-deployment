variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
}

variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
}

variable "router_dns_zone" {
  description = "DNS zone to use for the router"
  type        = string
}

variable "dashboard_dns_zone" {
  description = "DNS zone to use for dashboard"
  type        = string
}

variable "create" {
  description = "Indicates if tls certificates need to be created"
  type        = string
}

variable "cert_name" {
  description = "Azure cert name"
  type        = string
}

variable "issuer" {
  description = "Azure issuer name"
  type        = string
  default     = "Self"
}
