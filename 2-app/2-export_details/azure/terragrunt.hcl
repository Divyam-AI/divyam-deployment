# Export details (Azure): generates provider.yaml for helmfile with platform-specific configuration.
# Depends on: divyam_secrets (Key Vault name), iam_bindings (WIF client IDs),
#             divyam_object_storage (storage details), cloudsql (MySQL details when created).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "divyam_secrets" {
  config_path = "${get_repo_root()}/2-app/0-divyam_secrets/azure"
  mock_outputs = {
    key_vault_name = "mock-vault"
  }
}

dependency "iam_bindings" {
  config_path = "${get_repo_root()}/2-app/1-iam_bindings/azure"
  mock_outputs = {
    uai_client_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "divyam_object_storage" {
  config_path = "${get_repo_root()}/1-platform/0-divyam_object_storage/azure"
  mock_outputs = {
    router_requests_logs_storage_account_name = ""
    router_requests_logs_container_names      = []
  }
}

dependency "cloudsql" {
  config_path = "${get_repo_root()}/2-app/0-cloudsql/azure"
  mock_outputs = {
    mysql_server_fqdn  = ""
    mysql_database_name = ""
  }
}

locals {
  root      = include.root.locals.merged
  repo_root = get_repo_root()
  env       = local.root.env_name

  export_cfg = try(local.root.export_details, {})

  cloudsql_cfg     = try(local.root.cloudsql, {})
  cloudsql_created = try(local.cloudsql_cfg.create, false)

  key_vault_name    = try(local.root.divyam_secrets.store_name, "")
  storage_account   = try(one([for s in local.root.divyam_object_storages : s.storage_account_name if s.type == "router-requests-logs"]), "")
  storage_container = try(one([for s in local.root.divyam_object_storages : s.container_name if s.type == "router-requests-logs"]), "")
}

inputs = {
  environment       = local.env
  key_vault_name    = try(dependency.divyam_secrets.outputs.key_vault_name, local.key_vault_name)
  storage_account   = try(dependency.divyam_object_storage.outputs.router_requests_logs_storage_account_name, local.storage_account)
  storage_container = try(one(dependency.divyam_object_storage.outputs.router_requests_logs_container_names), local.storage_container)
  tenant_id         = get_env("ARM_TENANT_ID", "")
  wif_client_id_map = {
    "router-controller"     = try(dependency.iam_bindings.outputs.uai_client_ids["divyam-router-controller-${local.env}-sa_uai_client_id"], "")
    "mysql"                 = try(dependency.iam_bindings.outputs.uai_client_ids["mysql-${local.env}-sa_uai_client_id"], "")
    "clickhouse"            = try(dependency.iam_bindings.outputs.uai_client_ids["clickhouse-${local.env}-sa_uai_client_id"], "")
    "divyam-db-upgrades"    = try(dependency.iam_bindings.outputs.uai_client_ids["divyam-db-upgrades-${local.env}-sa_uai_client_id"], "")
    "divyam-evaluator"      = try(dependency.iam_bindings.outputs.uai_client_ids["divyam-evaluator-${local.env}-sa_uai_client_id"], "")
    "divyam-route-selector" = try(dependency.iam_bindings.outputs.uai_client_ids["divyam-route-selector-${local.env}-sa_uai_client_id"], "")
    "selector-training"     = try(dependency.iam_bindings.outputs.uai_client_ids["divyam-selector-training-${local.env}-sa_uai_client_id"], "")
    "superset-postgres"     = try(dependency.iam_bindings.outputs.uai_client_ids["superset-postgres-${local.env}-sa_uai_client_id"], "")
  }
  cluster_domain            = try(local.export_cfg.cluster_domain, "")
  image_pull_secret_enabled = try(local.export_cfg.image_pull_secret_enabled, true)
  output_path               = "${local.repo_root}/${try(local.export_cfg.output_dir, "k8s/values")}/provider.yaml"

  cloudsql_created = local.cloudsql_created
  mysql_host       = local.cloudsql_created ? try(dependency.cloudsql.outputs.mysql_server_fqdn, "") : ""
  mysql_port       = 3306
  mysql_database   = local.cloudsql_created ? try(dependency.cloudsql.outputs.mysql_database_name, "divyam_${local.env}") : "divyam_${local.env}"

  common_tags = try(include.root.inputs.common_tags, {})
  tag_globals = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = local.root.deployment_prefix
  }
}
