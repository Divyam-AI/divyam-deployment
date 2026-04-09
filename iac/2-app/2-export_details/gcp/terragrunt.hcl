# Export details (GCP): generates provider.yaml for helmfile with platform-specific configuration.
# Values from defaults.hcl; storage bucket from divyam_object_storage; databases from cloudsql (when created).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "divyam_object_storage" {
  config_path = "${get_repo_root()}/iac/1-platform/0-divyam_object_storage/gcp"
  mock_outputs = {
    router_requests_logs_bucket_name = ""
  }
}

dependency "cloudsql" {
  config_path = "${get_repo_root()}/iac/2-app/0-cloudsql/gcp"
  mock_outputs = {
    private_ip_address = ""
    database_name      = ""
  }
}

locals {
  root      = include.root.locals.merged
  repo_root = get_repo_root()
  env       = local.root.env_name

  export_cfg = try(local.root.export_details, {})
  lb_cfg     = try(local.root.divyam_load_balancer, {})

  cloudsql_cfg     = try(local.root.cloudsql, {})
  cloudsql_created = try(local.cloudsql_cfg.create, false)

  storage_bucket = try(one([for s in local.root.divyam_object_storages : s.container_name if s.type == "router-requests-logs"]), "")
}

inputs = {
  environment               = local.env
  project_id                = local.root.resource_scope.name
  storage_bucket            = try(dependency.divyam_object_storage.outputs.router_requests_logs_bucket_name, local.storage_bucket)
  cluster_domain            = try(local.export_cfg.cluster_domain, "")
  ingress_deploy            = true
  ingress_external          = try(local.lb_cfg.public, false)
  router_ingress_domain     = try(local.lb_cfg.router_dns, "")
  dashboard_ingress_domain  = try(local.lb_cfg.dashboard_dns, "")
  controlplane_ingress_domain = try(local.lb_cfg.controlplane_dns, "")
  deployment_mode          = trimspace(try(local.lb_cfg.controlplane_dns, "")) != "" ? "managed" : "onprem"
  image_pull_secret_enabled = try(local.export_cfg.image_pull_secret_enabled, false)
  output_path               = "${local.repo_root}/${try(local.export_cfg.output_dir, "k8s/values")}/provider.yaml"

  cloudsql_created = local.cloudsql_created
  mysql_host       = local.cloudsql_created ? (try(dependency.cloudsql.outputs.private_ip_address, null) == null ? "" : dependency.cloudsql.outputs.private_ip_address) : ""
  mysql_port       = 3306
  # TO FIX: default value flowing 'divyam', fix it to flow 'divyam_$ENV'
  mysql_database   = local.cloudsql_created ? try(dependency.cloudsql.outputs.database_name, "divyam_${local.env}") : "divyam_${local.env}"

  common_tags = try(include.root.inputs.common_tags, {})
  tag_globals = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = local.root.deployment_prefix
  }
}
