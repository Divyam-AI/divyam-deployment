variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "key_vault_name" {
  description = "Azure Key Vault name. Used to construct the vault URI (https://<name>.vault.azure.net/)."
  type        = string
}

variable "storage_container" {
  description = "Azure storage container name for platform storage_configs."
  type        = string
  default     = ""
}

variable "storage_account" {
  description = "Azure storage account name for platform storage_configs."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure AD tenant ID for workload identity federation."
  type        = string
  default     = ""
}

variable "wif_client_id_map" {
  description = "Map of workload name to Azure UAI client ID for workload identity federation."
  type        = map(string)
  default     = {}
}

variable "cluster_domain" {
  description = "Cluster domain for cross-cluster DNS. Leave empty for in-cluster."
  type        = string
  default     = ""
}

variable "ingress_deploy" {
  description = "Whether ingress chart resources should be deployed."
  type        = bool
  default     = true
}

variable "ingress_external" {
  description = "Whether ingress should use public frontend (false = private IP)."
  type        = bool
  default     = false
}

variable "router_ingress_domain" {
  description = "Router ingress host/domain."
  type        = string
  default     = ""
}

variable "dashboard_ingress_domain" {
  description = "Dashboard ingress host/domain."
  type        = string
  default     = ""
}

variable "controlplane_ingress_domain" {
  description = "Control-plane ingress host/domain for router control APIs."
  type        = string
  default     = ""
}

variable "deployment_mode" {
  description = "Deployment mode derived from controlplane DNS: managed when set, onprem otherwise."
  type        = string
  default     = "onprem"
}

variable "lb_enabled" {
  description = "Whether load balancer is enabled."
  type        = bool
  default     = true
}

locals {
  _validate_controlplane_domain = !(var.lb_enabled && var.deployment_mode == "managed" && trimspace(var.controlplane_ingress_domain) == "")
}

resource "terraform_data" "validate_controlplane_domain" {
  lifecycle {
    precondition {
      condition     = local._validate_controlplane_domain
      error_message = "controlplane ingress domain must be set when deployment_mode is \"managed\" and load balancer is enabled (divyam_load_balancer.dns_records.controlplane + private_dns_zone.name, or legacy controlplane_dns)."
    }
  }
}

variable "ingress_tls_enabled" {
  description = "Whether TLS is enabled for ingress at Application Gateway."
  type        = bool
  default     = false
}

variable "ingress_certificate_name" {
  description = "Application Gateway SSL certificate name used by ingress annotations."
  type        = string
  default     = ""
}

variable "image_pull_secret_enabled" {
  description = "Whether the cluster needs image pull secrets for a private registry."
  type        = bool
  default     = true
}

variable "monitoring_enabled" {
  description = "Top-level monitoring.enabled value written to provider.yaml."
  type        = bool
  default     = false
}

variable "monitoring_provider" {
  description = "Optional monitoring provider written to provider.yaml (for example: datadog)."
  type        = string
  default     = ""
}

variable "output_path" {
  description = "Absolute path for the generated provider.yaml file."
  type        = string
}

variable "cloudsql_created" {
  description = "Whether Cloud SQL (Azure MySQL Flexible Server) was created. When true, the databases section is included in provider.yaml."
  type        = bool
  default     = false
}

variable "mysql_host" {
  description = "MySQL host FQDN (Azure MySQL Flexible Server FQDN)."
  type        = string
  default     = ""
}

variable "mysql_port" {
  description = "MySQL port."
  type        = number
  default     = 3306
}

variable "mysql_database" {
  description = "MySQL database name."
  type        = string
  default     = ""
}
