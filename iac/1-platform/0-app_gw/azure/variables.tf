variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "backend_service_name" {
  description = "Base name for the backend service and associated resources (App Gateway, IPs, etc)."
  type        = string
}

variable "create_public_lb" {
  description = "Whether to create a public-facing Application Gateway (true) or internal (false). From defaults.hcl divyam_load_balancer.public."
  type        = bool
}

variable "create_ip" {
  description = "Whether to use a reserved/fixed IP (from defaults.hcl divyam_static_ip_load_balancer.create_ip)."
  type        = bool
  default     = true
}

variable "lb_ip" {
  description = "Static private IP for internal LB when create_public_lb is false (from defaults.hcl divyam_static_ip_load_balancer.ip). Must be in the app_gw subnet."
  type        = string
  default     = null
}

variable "lb_ip_name" {
  description = "When create_public_lb: name for new public IP or name of existing if create_public_ip = false (from defaults.hcl divyam_load_balancer.public_ip_name)."
  type        = string
  default     = null
}

variable "create_public_ip" {
  description = "When true and create_public_lb, create new public IP; when false, use existing by lb_ip_name (from defaults.hcl divyam_load_balancer.create_public_ip)."
  type        = bool
  default     = true
}

variable "location" {
  description = "Azure region where the resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group in which to deploy the Application Gateway and related resources."
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Resource group of the VNet"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet name to resource ID (optional when vnet_name/vnet_resource_group_name/vnet_subnet_name are used for lookup)"
  type        = map(string)
  default     = {}
}

variable "vnet_subnet_name" {
  description = "Name of the subnet to use for the Application Gateway"
  type        = string
}

variable "certificate_secret_id" {
  description = "Optional TLS certificate Key Vault secret ID"
  type        = string
  default     = null
}

variable "azure_key_vault_id" {
  description = "Azure Key Vault ID (for App Gateway certificate access). Ignored when azure_key_vault_name is set."
  type        = string
  default     = null
}

variable "azure_key_vault_name" {
  description = "Azure Key Vault name to look up in resource_group_name (from defaults.hcl divyam_secrets.store_name)"
  type        = string
  default     = null
}

variable "tls_enabled" {
  description = "Whether TLS is enabled at the Application Gateway (from defaults.hcl divyam_static_ip_load_balancer.tls_enabled)."
  type        = bool
}

variable "waf_enabled" {
  description = "Whether WAF is enabled on the Application Gateway (from defaults.hcl divyam_load_balancer.waf_enabled)."
  type        = bool
  default     = true
}

variable "create_waf" {
  description = "When true, create WAF policy in-module; when false and waf_enabled, fetch existing by waf_policy_name (from defaults.hcl divyam_load_balancer.create_waf)."
  type        = bool
  default     = true
}

variable "waf_policy_name" {
  description = "Name for created WAF policy or name of existing to fetch when create_waf = false (from defaults.hcl divyam_load_balancer.waf_policy_name)."
  type        = string
  default     = null
}

variable "waf_deny_ip_ranges" {
  description = "IP/CIDR list to block by WAF custom rule (from defaults.hcl divyam_load_balancer.waf_deny_ip_ranges)."
  type        = list(string)
  default     = []
}

variable "waf_allow_ip_ranges" {
  description = "If non-empty, only these IP/CIDR allowed; deny list still applied first (from defaults.hcl divyam_load_balancer.waf_allow_ip_ranges)."
  type        = list(string)
  default     = []
}

variable "create_ssl_cert" {
  description = "Whether to create/use SSL cert (from defaults.hcl divyam_static_ip_load_balancer.create_ssl_cert). Used for wiring cert resources."
  type        = bool
  default     = false
}

variable "cert_name" {
  description = "Name of the certificate in Key Vault (from defaults.hcl divyam_static_ip_load_balancer.ssl_cert_name)."
  type        = string
  default     = null
}

variable "router_dns_zone" {
  description = "Router DNS name for certificate subject and SAN (from defaults.hcl divyam_load_balancer.router_dns)."
  type        = string
  default     = null
}

variable "dashboard_dns_zone" {
  description = "Dashboard DNS name for certificate SAN (from defaults.hcl divyam_load_balancer.dashboard_dns)."
  type        = string
  default     = null
}

variable "controlplane_dns_zone" {
  description = "Control-plane DNS name for certificate SAN and DNS A record (from defaults.hcl divyam_load_balancer.controlplane_dns)."
  type        = string
  default     = null
}

variable "cert_issuer" {
  description = "Azure Key Vault certificate issuer (e.g. Self for self-signed)."
  type        = string
  default     = "Self"
}

variable "cert_validity_in_months" {
  description = "Validity of the certificate in months."
  type        = number
  default     = 12
}

variable "create_dns_records" {
  description = "When true and router_dns_zone/dashboard_dns_zone are set, create Private DNS zones and A records mapping those names to the LB IP (public when public=true, private otherwise)."
  type        = bool
  default     = true
}

variable "dns_record_ttl" {
  description = "TTL in seconds for DNS A records."
  type        = number
  default     = 300
}
