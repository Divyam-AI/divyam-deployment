include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "vnet" {
  config_path = "../../1-vnet/azure"

  mock_outputs = {
    vnet_id             = ""
    subnet_id           = ""
    subnet_name         = "subnet"
    subnet_prefix       = "10.0.0.0/24"
    app_gw_subnet_id    = ""
    app_gw_subnet_name  = "app-gw-subnet"
    app_gw_subnet_prefix = "10.0.8.0/27"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

# Local state like 1-vnet / 2-nat; bastion depends on VNet.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root           = include.root.locals.merged
  bastion_config = try(local.root.bastion, { create = false, bastion_name = "${local.root.deployment_prefix}-bastion", vnet_subnet_name = null })
}

inputs = merge(
  {
    create              = try(local.bastion_config.create, false)
    location             = local.root.region
    environment          = local.root.env_name
    common_tags          = try(local.root.common_tags, {})
    resource_group_name  = local.root.resource_scope.name
    bastion_name         = try(local.bastion_config.bastion_name, "${local.root.deployment_prefix}-bastion")
    vm_size              = try(local.bastion_config.vm_size, "Standard_B1s")
    admin_username       = try(local.bastion_config.admin_username, "azureuser")
    ssh_public_key_path  = try(local.bastion_config.ssh_public_key_path, "~/.ssh/id_rsa.pub")
    vnet_id              = dependency.vnet.outputs.vnet_id
    # Build from 1-vnet outputs (dependency only available in inputs, not in locals).
    subnet_ids = {
      (dependency.vnet.outputs.subnet_name)        = dependency.vnet.outputs.subnet_id
      (dependency.vnet.outputs.app_gw_subnet_name) = dependency.vnet.outputs.app_gw_subnet_id
    }
    subnet_names = [dependency.vnet.outputs.subnet_name, dependency.vnet.outputs.app_gw_subnet_name]
    subnet_prefixes = {
      (dependency.vnet.outputs.subnet_name)        = dependency.vnet.outputs.subnet_prefix
      (dependency.vnet.outputs.app_gw_subnet_name) = dependency.vnet.outputs.app_gw_subnet_prefix
    }
    vnet_subnet_name = try(local.bastion_config.vnet_subnet_name, dependency.vnet.outputs.subnet_name)
    # Kubectl: only when bastion section has configure_kubectl = true; cluster details from k8s section.
    configure_kubectl = try(local.bastion_config.configure_kubectl, false)
    cluster_name      = try(local.root.k8s.name, "")
    tag_globals          = try(include.root.inputs.tag_globals, {})
    tag_context         = {
      resource_name = try(local.bastion_config.bastion_name, "${local.root.deployment_prefix}-bastion")
    }
  }
)

