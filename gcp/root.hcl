locals {
  env_name = get_env("ENV")
  install_config = read_terragrunt_config("${get_repo_root()}/deployment/envs/${local.env_name}.hcl").locals
  project = local.install_config.common_vars.project_id
  region = local.install_config.common_vars.region
  environment = local.install_config.common_vars.environment
  cloud_provider = local.install_config.common_vars.cloud_provider
}

# You can add any common hooks or extra_arguments here if needed.

# Save the state in GCS bucket

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "divyam-production-terraform-state-bucket"
    project        = "divyam-production"
    prefix         = "${local.environment}__${local.project}__${local.region}/${path_relative_to_include()}/"
    location       = "asia-south1"
 }
}
