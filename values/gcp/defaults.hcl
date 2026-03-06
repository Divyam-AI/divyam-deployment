#----------------------------------------------
# GCP-specific deployment values.
# Merged with values/defaults.hcl. Region/zone come from common (REGION, ZONE env).
# Set via env: GOOGLE_CREDENTIALS, ORG_ID, FOLDER_ID, BILLING_ACCOUNT_ID
#----------------------------------------------
locals {
  cloud_provider = "gcp"

  #project_id      = get_env("GCP_PROJECT_ID")
  #project_name   = get_env("GCP_PROJECT_NAME")
  #org_id         = get_env("ORG_ID")
  #folder_id      = get_env("FOLDER_ID")
  #billing_account = get_env("BILLING_ACCOUNT_ID")

  # Remote state backend for all modules except 0-resource_scope and 1-terraform_state_*
  # (those use local state; prefix is built in root from path_relative_to_include())
  remote_state = {
    backend = "gcs"
  }

  # Provider block for root terragrunt generate; only loaded when CLOUD_PROVIDER=gcp
  provider_block = <<-EOT
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  # Use Application Default Credentials (gcloud auth application-default login)
  # or set GOOGLE_APPLICATION_CREDENTIALS.
}
EOT
}
