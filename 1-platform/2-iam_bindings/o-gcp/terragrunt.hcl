# IAM bindings (GCP): Service accounts, project/bucket IAM, and Workload Identity bindings.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "divyam_object_storage" {
  config_path = "../../0-divyam_object_storage/gcp"
  mock_outputs = {
    router_requests_logs_bucket_name = "mock-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = include.root.locals.merged
}

inputs = {
  env_name                = local.root.env_name
  project_id              = local.root.resource_scope.name
  region                  = local.root.region
  common_tags             = try(include.root.inputs.common_tags, {})
  tag_globals             = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = local.root.deployment_prefix
  }
  router_logs_bucket_name = dependency.divyam_object_storage.outputs.router_requests_logs_bucket_name
}