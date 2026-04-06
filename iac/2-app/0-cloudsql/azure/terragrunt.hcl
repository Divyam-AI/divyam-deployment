# Azure Database for MySQL Flexible Server (0-cloudsql). Config from values/defaults.hcl cloudsql.
# VNet looked up by name from defaults (no dependency on 0-foundation). Tags passed like 1-k8s.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

locals {
  root       = include.root.locals.merged
  cloudsql   = try(local.root.cloudsql, {})
  instance_name = try(local.cloudsql.instance_name, "divyam-${local.root.env_name}-cloudsql")
  vnet_name  = try(local.root.vnet.name, "")
  vnet_scope = try(local.root.vnet.scope_name, local.root.resource_scope.name)
}

inputs = {
  create                    = try(local.cloudsql.create, false)
  resource_group_name        = local.root.resource_scope.name
  location                  = local.root.region
  vnet_name                 = local.vnet_name
  vnet_resource_group_name   = local.vnet_scope
  server_name                = local.instance_name
  administrator_login        = get_env("TF_VAR_divyam_db_user", "divyamadmin")
  administrator_password     = get_env("TF_VAR_divyam_db_password", "changeme")
  database_name              = get_env("TF_VAR_divyam_db_name", "divyam")

  common_tags   = try(local.root.common_tags, {})
  tag_globals   = try(include.root.inputs.tag_globals, {})
  tag_context   = {
    resource_name = local.instance_name
  }
}