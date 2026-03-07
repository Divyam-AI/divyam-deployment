include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "secrets" {
  path   = "../common/secrets_input.hcl"
  expose = true
}

terraform {
  source = "./"
}

# Terraform does not allow variables in module source; generate file with literal path.
generate "common_module" {
  path      = "common_module.tf"
  if_exists = "overwrite"
  contents  = <<EOF
module "common" {
  source = "${get_terragrunt_dir()}/../common"
  input  = var.secrets_input
}
EOF
}

dependency "tfstate_gcs" {
  config_path  = "../../../0-foundation/2-terraform_state_blob_storage/gcp"
  skip_outputs = true
}

locals {
  root         = include.root.locals.merged
  secrets_cfg  = try(local.root.divyam_secrets, {})
  scope_name   = local.root.resource_scope.name
  secrets_input = merge(include.secrets.locals.secrets_input, { env = local.root.env_name })
}

# Pass divyam_secrets config from defaults. secrets_input from common/secrets_input.hcl.
inputs = merge(
  {
    project_id     = local.scope_name
    location       = local.root.region
    environment    = local.root.env_name
    create_secrets = try(local.secrets_cfg.create_secrets, true)
    secrets_input  = local.secrets_input
    common_tags    = try(include.root.inputs.common_tags, {})
    tag_globals    = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.deployment_prefix
    }
  }
)
