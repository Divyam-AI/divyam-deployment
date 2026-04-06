include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Run 0-resource_scope before this module (same order as dependency, but we use values for project_id to avoid dependency output issues in run-all).
dependencies {
  paths = ["../../0-resource_scope/gcp"]
}

terraform {
  source = "./"
}

remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    path = include.root.locals.local_state_file
  }
}

locals {
  root       = include.root.locals.merged
  apis_config = try(local.root.apis, { enabled = true, apis = [] })
  # Optional: add common APIs here if not provided via values
  default_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "dns.googleapis.com",
    "networkmanagement.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
  apis = length(try(local.apis_config.apis, [])) > 0 ? local.apis_config.apis : local.default_apis
}

inputs = merge(
  {
    # Use same source as 0-resource_scope: values file resource_scope.name (GCP project ID)
    project_id = local.root.resource_scope.name
    enabled    = try(local.apis_config.enabled, true)
    apis       = local.apis
  }
)