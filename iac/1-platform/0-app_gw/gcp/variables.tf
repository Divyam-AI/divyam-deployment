variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP region"
}

variable "create_public_lb" {
  type        = bool
  default     = false
  description = "Create public (external) LB when true, internal when false (from defaults.hcl divyam_load_balancer.public)"
}

variable "tls_enabled" {
  type        = bool
  default     = false
  description = "Enable TLS/HTTPS (from defaults.hcl divyam_load_balancer.tls_enabled). When true with create_ssl_cert, cert may be created in-module."
}

variable "lb_ip" {
  type        = string
  default     = null
  description = "Static private IP for internal LB (from defaults.hcl divyam_load_balancer.ip). Must be in the app_gw subnet."
}

variable "ssl_certificate_id" {
  type        = string
  default     = null
  description = "SSL certificate self link or ID for HTTPS (optional when create_ssl_cert is true and domains are set)"
}

variable "create_ssl_cert" {
  type        = bool
  default     = false
  description = "When true and tls_enabled, create a Google-managed SSL cert (from defaults.hcl divyam_load_balancer.create_ssl_cert)"
}

variable "ssl_cert_name" {
  type        = string
  default     = null
  description = "Name for the managed SSL certificate when create_ssl_cert is true (from defaults.hcl divyam_load_balancer.ssl_cert_name)"
}

variable "router_dns" {
  type        = string
  default     = ""
  description = "Router DNS name for managed SSL cert and DNS (from defaults.hcl divyam_load_balancer.router_dns)"
}

variable "dashboard_dns" {
  type        = string
  default     = ""
  description = "Dashboard DNS name for managed SSL cert and DNS (from defaults.hcl divyam_load_balancer.dashboard_dns)"
}

variable "static_ip_name" {
  type        = string
  default     = null
  description = "When create_public_lb: name for new global static IP or name of existing if create_public_ip = false (from defaults.hcl divyam_load_balancer.public_ip_name)"
}

variable "create_public_ip" {
  type        = bool
  default     = true
  description = "When true and create_public_lb, create new global static IP; when false, use existing by static_ip_name (from defaults.hcl divyam_load_balancer.create_public_ip)"
}

variable "private_ip_name" {
  type        = string
  default     = null
  description = "Name for the private (internal) IP resource when create_public_lb is false (from defaults.hcl divyam_load_balancer.private_ip_name)"
}

variable "cloud_armor_policy_id" {
  type        = string
  default     = null
  description = "Cloud Armor policy ID (optional). When null and waf_enabled: create in-module if create_waf, else fetch by waf_policy_name."
}

variable "waf_enabled" {
  type        = bool
  default     = true
  description = "Enable WAF/Cloud Armor (from defaults.hcl divyam_load_balancer.waf_enabled)."
}

variable "create_waf" {
  type        = bool
  default     = true
  description = "When true create WAF policy in-module; when false and waf_enabled fetch existing by waf_policy_name (from defaults.hcl divyam_load_balancer.create_waf)."
}

variable "waf_policy_name" {
  type        = string
  default     = null
  description = "Name for created Cloud Armor policy or name of existing to fetch when create_waf = false (from defaults.hcl divyam_load_balancer.waf_policy_name)."
}

variable "waf_deny_ip_ranges" {
  type        = list(string)
  default     = []
  description = "IP/CIDR ranges to deny in WAF policy when create_waf (from defaults.hcl divyam_load_balancer.waf_deny_ip_ranges)."
}

variable "waf_allow_ip_ranges" {
  type        = list(string)
  default     = []
  description = "When non-empty: only these IP/CIDR allowed (allowlist) when create_waf (from defaults.hcl divyam_load_balancer.waf_allow_ip_ranges)."
}

variable "backend_service_name" {
  type        = string
  default     = "gke-backend-service"
  description = "Name of the backend service and related resources"
}

variable "target_proxy_name" {
  type        = string
  default     = "gke-https-proxy"
  description = "Base name for target HTTP(S) proxies"
}

variable "gke_neg_names" {
  type        = list(string)
  default     = []
  description = "List of GKE NEG names (one per zone)"
}

variable "gke_neg_zones" {
  type        = list(string)
  default     = []
  description = "List of zones matching the NEG names"
}

variable "app_gw_subnet_name" {
  type        = string
  description = "App-gateway subnet name from vnet.app_gw_subnet.name (required); subnet is fetched by this name"
}

variable "network_name" {
  type        = string
  description = "Network name from vnet.name (required); network self link is built from project_id and this name"
  default     = "default"
}
