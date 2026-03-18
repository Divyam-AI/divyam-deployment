include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "vnet" {
  config_path = "../../1-vnet/gcp"

  mock_outputs = {
    vnet_name           = "default"
    vnet_resource_group_name = ""
    subnet_id           = ""
    subnet_name         = "default"
    subnet_prefix       = "10.0.0.0/24"
    app_gw_subnet_id    = ""
    app_gw_subnet_name  = "app-gw-subnet"
    app_gw_subnet_prefix = "10.0.8.0/26"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

dependency "nat" {
  config_path = "../../2-nat/gcp"
  skip_outputs = true
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

# Local state like 1-vnet / 2-nat; bastion depends on VPC.
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
  root           = include.root.locals.merged
  bastion_config = try(local.root.bastion, { create = false, bastion_name = "${local.root.deployment_prefix}-bastion" })
  project_id     = local.root.resource_scope.name
  region         = local.root.region
  zone           = local.root.zone
}

inputs = merge(
  {
    create       = try(local.bastion_config.create, false)
    project_id   = local.project_id
    region       = local.region
    zone         = local.zone
    # Use dependency outputs only when VNet is in the same project; otherwise use current config so bastion uses its project (avoids cross-project mismatch when vnet state was applied with different values).
    network      = dependency.vnet.outputs.vnet_resource_group_name == local.project_id ? dependency.vnet.outputs.vnet_name : try(local.root.vnet.name, dependency.vnet.outputs.vnet_name)
    subnet       = dependency.vnet.outputs.vnet_resource_group_name == local.project_id ? dependency.vnet.outputs.subnet_id : "projects/${local.project_id}/regions/${local.region}/subnetworks/${try(local.root.vnet.subnet.name, dependency.vnet.outputs.subnet_name)}"
    bastion_name = try(local.bastion_config.bastion_name, "${local.root.deployment_prefix}-bastion")
    machine_type = try(local.bastion_config.machine_type, "e2-micro")
    spot_instance = try(local.bastion_config.spot_instance, false)
    tags         = try(local.bastion_config.tags, ["bastion"])
    # Kubectl: only when bastion section has configure_kubectl = true; cluster details from k8s section.
    configure_kubectl   = try(local.bastion_config.configure_kubectl, false)
    cluster_name       = try(local.root.k8s.name, "")
    cluster_region     = local.region
    cluster_project_id = local.project_id

    common_tags  = try(local.root.common_tags, {})
    tag_globals  = try(include.root.inputs.tag_globals, {})
    tag_context  = { resource_name = try(local.bastion_config.bastion_name, "${local.root.deployment_prefix}-bastion") }
  }
)
