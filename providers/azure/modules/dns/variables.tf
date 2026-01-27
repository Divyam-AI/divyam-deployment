variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
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

variable "vnet_id" {
  description = "ID of the Virtual Network"
  type        = string
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway for AGIC integration"
  type        = string
}

variable "app_gateway_id" {
  description = "ID of the Application Gateway for AGIC integration"
  type        = string
}

variable "app_gateway_lb_ip" {
  description = "IP address of the Application Gateway (Public or Private)"
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

variable "dns_record_ttl" {
  description = "TTL in seconds for DNS A records"
  type        = number
  default     = 300
}
