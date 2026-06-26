include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

locals {
  root = include.root.locals.merged
  # Evalm8 lakeFS storage is gated by stack in defaults.hcl, empty list for a router-only deployment.
  storages = concat(try(local.root.divyam_object_storages, []), try(local.root.evalm8_object_storages, []))
  # Group by storage_account_name (logical group key); each group -> one entry with bucket_names (container_name = GCS bucket name).
  buckets = length(local.storages) > 0 ? {
    for name in distinct([for s in local.storages : s.storage_account_name]) :
    name => {
      bucket_names = [for s in local.storages : s.container_name if s.storage_account_name == name]
      create       = length([for s in local.storages : s if s.storage_account_name == name && try(s.create, true)]) > 0
      type         = try([for s in local.storages : s.type if s.storage_account_name == name][0], null)
    }
  } : {}
  scope_name                       = local.root.resource_scope.name
  router_requests_logs_storage_key = try([for k, v in local.buckets : k if v.type == "router-requests-logs"][0], null)
  # Key in buckets whose type is lakefs-data, the evalm8 lakeFS data store, for the evalm8_lakefs_bucket_name output.
  evalm8_lakefs_storage_key = try([for k, v in local.buckets : k if v.type == "lakefs-data"][0], null)
}

inputs = merge(
  {
    project_id                       = local.scope_name
    location                         = local.root.region
    environment                      = local.root.env_name
    buckets                          = local.buckets
    router_requests_logs_storage_key = local.router_requests_logs_storage_key
    evalm8_lakefs_storage_key        = local.evalm8_lakefs_storage_key
    common_tags                      = try(local.root.common_tags, {})
    tag_globals                      = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.deployment_prefix
    }
  }
)
