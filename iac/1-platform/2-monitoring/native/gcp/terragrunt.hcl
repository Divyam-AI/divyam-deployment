# GCP Cloud Monitoring log bucket. GKE logging/GMP remain on 1-k8s/gcp (cluster resource).

include "monitoring" {
  path   = "${get_parent_terragrunt_dir()}/../../terragrunt.hcl"
  expose = true
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

generate "provider_gcp" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
}
EOT
}

locals {
  root            = include.root.locals.merged
  monitoring_cfg  = try(local.root.monitoring, {})
  native_cfg      = try(local.monitoring_cfg.native, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
  k8s_obs         = try(local.root.k8s.observability, {})

  monitoring_enabled = try(local.monitoring_cfg.create, true)
  native_enabled     = local.monitoring_enabled && !local.datadog_enabled

  cluster_name = coalesce(
    try(local.native_cfg.gmp_cluster_name, null),
    local.root.k8s.name
  )
}

inputs = {
  enabled = local.native_enabled
  project_id = coalesce(try(local.native_cfg.gcp_project_id, null), local.root.resource_scope.name)
  logs_retention_days = min(3650, max(1, try(local.native_cfg.logs_retention_days, try(local.k8s_obs.logs_retention_days, 30))))
  manage_project_log_bucket = try(local.native_cfg.manage_project_log_bucket, true)

  common_tags = try(local.root.common_tags, {})
  tag_globals = try(include.root.inputs.tag_globals, {})
  tag_context = { resource_name = "${local.root.deployment_prefix}-monitoring" }
}

exclude {
  if      = local.datadog_enabled || !local.monitoring_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
