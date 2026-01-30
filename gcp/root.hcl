#----------------------------------------------
# Generate deployment configuration for all
# Divyam GCP components.
#----------------------------------------------
locals {
  install_config = read_terragrunt_config("${get_repo_root()}/gcp/config/config-merge.hcl").locals.install_config
  common_vars    = local.install_config.common_vars

  project     = local.common_vars.project_id
  region      = local.common_vars.region
  environment = local.common_vars.environment

  common_tags = try(local.install_config.common_tags, {})

  # GCS remote state config from install_config
  gcs_backend = {
    bucket   = local.install_config.gcs_remote_state.bucket
    project  = local.install_config.gcs_remote_state.project
    location = local.install_config.gcs_remote_state.location
    prefix   = "${local.environment}__${local.project}__${local.region}/${path_relative_to_include()}/"
  }
}

# Automatically generate provider block in every module
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = "${local.project}"
  region  = "${local.region}"
}

provider "google-beta" {
  project = "${local.project}"
  region  = "${local.region}"
}
EOF
}

# Save the state in GCS bucket
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket   = local.gcs_backend.bucket
    project  = local.gcs_backend.project
    prefix   = local.gcs_backend.prefix
    location = local.gcs_backend.location
  }
}

# Shared inputs available to all child modules
inputs = {
  project_id  = local.project
  region      = local.region
  environment = local.environment
  common_tags = local.common_tags
}
