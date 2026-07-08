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

variable "evalm8_lakefs_bucket" {
  description = "GCS bucket name for the evalm8 lakeFS store. Written under evalm8.storage.gcp.storage_configs.bucket so the helmfile resolves the lakefs chart objectStorage. Empty when stack is router."
  type        = string
  default     = ""
}

variable "evalm8_storage_type" {
  description = "evalm8 lakeFS storage backend written into provider.yaml platform.evalm8.storage.type, mapped by the helmfile to the lakefs chart objectStorage type. One of pvc, gcs, s3. Empty when stack is router."
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

variable "image_pull_secret_enabled" {
  description = "Whether the cluster needs image pull secrets for a private registry."
  type        = bool
  default     = false
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

variable "stack" {
  description = "Which chart stack helmfile deploys, written to provider.yaml as top-level `stack`: evalm8 | router | both. Empty omits the key (helmfile then deploys all stacks)."
  type        = string
  default     = ""
  validation {
    condition     = contains(["", "evalm8", "router", "both"], var.stack)
    error_message = "stack must be one of: evalm8, router, both (or empty to omit the key)."
  }
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
