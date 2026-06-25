# IAM bindings (GCP): Service accounts, project/bucket IAM, and Workload Identity bindings.
# Bucket name for router logs comes from defaults.hcl (divyam_object_storages type = \"router-requests-logs\").

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/2-app/1-iam_bindings//gcp"
}

# lakeFS bucket comes from the object_storage unit. Only consumed when stack is not router.
dependency "divyam_object_storage" {
  config_path = "${get_repo_root()}/iac/1-platform/0-divyam_object_storage/gcp"
  mock_outputs = {
    evalm8_lakefs_bucket_name = ""
  }
}

locals {
  root = include.root.locals.merged
  # From defaults.hcl: bucket name for router-requests-logs (container_name in divyam_object_storages).
  router_logs_bucket_name = try(one([for s in local.root.divyam_object_storages : s.container_name if s.type == "router-requests-logs"]), null)
  # Plan fallback: when the object_storage unit has no state yet, derive the lakeFS bucket name directly
  # from values so the evalm8 IAM path still validates under local-backend sandbox runs.
  evalm8_lakefs_bucket_name = try(one([for s in try(local.root.evalm8_object_storages, []) : s.container_name if s.type == "lakefs-data"]), null)
}

inputs = {
  env_name    = local.root.env_name
  project_id  = local.root.resource_scope.name
  region      = local.root.region
  common_tags = try(include.root.inputs.common_tags, {})
  tag_globals = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = local.root.deployment_prefix
  }
  router_logs_bucket_name   = local.router_logs_bucket_name
  stack                     = try(local.root.stack, "both")
  evalm8_lakefs_bucket_name = try(local.root.stack, "both") != "router" ? try(dependency.divyam_object_storage.outputs.evalm8_lakefs_bucket_name, local.evalm8_lakefs_bucket_name) : null
}
