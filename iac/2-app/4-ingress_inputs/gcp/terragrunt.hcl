# Ingress input resources (GCP): reserved IPs, managed SSL certs, Cloud Armor policies referenced by
# the GKE Ingress. Config comes from defaults.hcl `ingress_inputs`. No cross-unit dependencies.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

locals {
  root       = include.root.locals.merged
  scope_name = local.root.resource_scope.name
}

inputs = {
  project_id     = local.scope_name
  ingress_inputs = try(local.root.ingress_inputs, {})
  common_tags    = try(local.root.common_tags, {})
  tag_globals    = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = local.root.deployment_prefix
  }
}
