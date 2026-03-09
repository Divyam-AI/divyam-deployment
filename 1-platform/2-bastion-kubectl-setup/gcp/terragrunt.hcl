# Run setup-kubectl on the bastion without user intervention.
# No dependency on bastion module: run when bastion is configured for creation (values) and 1-k8s is up.
# Bastion name/zone/project from values; cluster_trigger from 1-k8s dependency.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

remote_state {
  backend = "local"
  config  = { path = "terraform.tfstate" }
}

dependency "k8s" {
  config_path = "../1-k8s/gcp"
  mock_outputs = {
    cluster_endpoints = {}
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
  create           = local.run_setup
  bastion_name     = try(local.bastion_config.bastion_name, "${local.root.deployment_prefix}-bastion")
  bastion_zone     = local.root.zone
  project_id       = local.root.resource_scope.name
  cluster_trigger  = jsonencode(dependency.k8s.outputs.cluster_endpoints)
}
