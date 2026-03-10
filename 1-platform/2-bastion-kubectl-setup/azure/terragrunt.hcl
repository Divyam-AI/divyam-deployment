# Run setup-kubectl on the bastion without user intervention.
# No dependency on bastion module: run when bastion is configured for creation (values) and 1-k8s is up.
# Bastion public IP is fetched from Azure; cluster_id from 1-k8s dependency.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

# Override root's provider.tf so we have a single terraform block with both azurerm and null
# (use a different generate block name to avoid conflict with root's generate "provider").
generate "provider_bastion_setup" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.57.0" }
    null    = { source = "hashicorp/null" }
  }
}
provider "azurerm" {
  features {}
  subscription_id = "${get_env("ARM_SUBSCRIPTION_ID")}"
  tenant_id       = "${get_env("ARM_TENANT_ID")}"
}
EOT
}

remote_state {
  backend = "local"
  config  = { path = include.root.locals.local_state_file }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

dependency "k8s" {
  config_path = "../../1-k8s/azure"
  mock_outputs = {
    aks_cluster_id = ""
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root           = include.root.locals.merged
  bastion_config = try(local.root.bastion, { create = false, configure_kubectl = false })
  k8s_config     = try(local.root.k8s, { setup_kubectl_on_bastion = false })
  # Module enabled only by k8s.setup_kubectl_on_bastion. bastion.configure_kubectl is only for "cluster pre-created, only bastion setup" (installs script on bastion at create time).
  run_setup      = try(local.k8s_config.setup_kubectl_on_bastion, false)
}

inputs = {
  create                  = local.run_setup
  bastion_name            = try(local.bastion_config.bastion_name, "${local.root.deployment_prefix}-bastion")
  resource_group_name     = local.root.resource_scope.name
  bastion_admin_username  = try(local.bastion_config.admin_username, "azureuser")
  ssh_private_key_path    = try(local.bastion_config.ssh_private_key_path, replace(try(local.bastion_config.ssh_public_key_path, "~/.ssh/id_rsa.pub"), ".pub", ""))
  cluster_id              = dependency.k8s.outputs.aks_cluster_id
}
