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
    app_gw_subnet_prefix = "10.0.8.0/27"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

# Local state like 1-vnet / 2-nat; bastion depends on VPC.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
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
    network      = dependency.vnet.outputs.vnet_name
    subnet       = dependency.vnet.outputs.subnet_id
    bastion_name = try(local.bastion_config.bastion_name, "${local.root.deployment_prefix}-bastion")
    machine_type = try(local.bastion_config.machine_type, "e2-micro")
    tags         = try(local.bastion_config.tags, ["bastion"])
  }
)
