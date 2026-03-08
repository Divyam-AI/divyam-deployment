include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "resource_scope" {
  config_path = "../../0-resource_scope/gcp"

  mock_outputs = {
    project_id = "mock-project"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root       = include.root.locals.merged
  apis_config = try(local.root.apis, { enabled = true, apis = [] })
  # Optional: add common APIs here if not provided via values
  default_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "dns.googleapis.com",
    "networkmanagement.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
  apis = length(try(local.apis_config.apis, [])) > 0 ? local.apis_config.apis : local.default_apis
}

inputs = merge(
  {
    project_id = dependency.resource_scope.outputs.project_id
    enabled    = try(local.apis_config.enabled, true)
    apis       = local.apis
  }
)