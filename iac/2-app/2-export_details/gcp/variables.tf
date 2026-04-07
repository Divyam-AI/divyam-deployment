variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "project_id" {
  description = "GCP project ID (used as secretsProjectId in provider.yaml)."
  type        = string
}

variable "storage_bucket" {
  description = "GCS bucket name for platform storage_configs."
  type        = string
  default     = ""
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
  description = "Whether ingress should use public frontend (false = private/internal ingress)."
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

variable "image_pull_secret_enabled" {
  description = "Whether the cluster needs image pull secrets for a private registry."
  type        = bool
  default     = false
}

variable "output_path" {
  description = "Absolute path for the generated provider.yaml file."
  type        = string
}

variable "cloudsql_created" {
  description = "Whether Cloud SQL was created. When true, the databases section is included in provider.yaml."
  type        = bool
  default     = false
}

variable "mysql_host" {
  description = "MySQL host IP (Cloud SQL private IP)."
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
