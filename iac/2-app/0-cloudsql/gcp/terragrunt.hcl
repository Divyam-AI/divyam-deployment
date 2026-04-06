# Cloud SQL (GCP). Config from values/defaults.hcl cloudsql. References gcp/cloudsql module.
# VNet/network by name from defaults (no dependency on 0-foundation). Tags passed like 1-k8s.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

# Provider with project/region (root's provider has no project).
generate "provider_google" {
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
  region  = var.region
}
EOT
}

locals {
  root      = include.root.locals.merged
  cloudsql  = try(local.root.cloudsql, {})
  project   = local.root.resource_scope.name
  vnet_name = try(local.root.vnet.name, "default")
}

inputs = merge(
  {
    create            = try(local.cloudsql.create, false)
    instance_name     = try(local.cloudsql.instance_name, "divyam-${local.root.env_name}-cloudsql")
    project_id        = local.project
    region            = local.root.region
    vpc_network_name  = local.vnet_name
    vpc_network       = "projects/${local.project}/global/networks/${local.vnet_name}"
    divyam_db_user    = get_env("TF_VAR_divyam_db_user", "divyam")
    divyam_db_password = get_env("TF_VAR_divyam_db_password", "changeme")
    divyam_db_name    = get_env("TF_VAR_divyam_db_name", "divyam")

    common_tags   = try(local.root.common_tags, {})
    tag_globals   = try(include.root.inputs.tag_globals, {})
    tag_context   = {
      resource_name = try(local.cloudsql.instance_name, "divyam-${local.root.env_name}-cloudsql")
    }
  }
)