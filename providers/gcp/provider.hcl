#----------------------------------------------
# GCP Provider Configuration
# Contains: backend config, provider block, defaults
#----------------------------------------------

locals {
  # Environment variables for GCP
  project_id = get_env("GCP_PROJECT_ID", "divyam-production")
  region     = get_env("GCP_REGION", "asia-south1")
  env_name   = get_env("ENV", "dev")

  # Backend type
  backend_type = "gcs"

  # GCS backend configuration
  backend_config = {
    bucket   = "divyam-pre-production-terraform-state-bucket"
    project  = "anurag-workspace"
    prefix   = "${local.env_name}__${local.project_id}__${local.region}/${path_relative_to_include()}/"
    location = "asia-south1"
  }

  # Provider block to be generated
  provider_block = <<EOF
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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}

provider "google" {
  project = "${local.project_id}"
  region  = "${local.region}"
}

provider "google-beta" {
  project = "${local.project_id}"
  region  = "${local.region}"
}
EOF

  # Default values for GCP
  defaults = {
    region     = local.region
    project_id = local.project_id
  }

  # GCP-specific: modules that need local state (bootstrap)
  # GCP doesn't have the same circular dependency issues as Azure
  bootstrap_modules = []

  # Module config key mapping (used by _common patterns)
  module_config_keys = {
    kubernetes    = "gke"
    network       = "shared_vpc"
    storage       = "gcs"
    secrets       = "secrets"
    load_balancer = "elb"
    monitoring    = "alerts"
    iam           = "iam_bindings"
    bastion       = "bastion_host"
    helm          = "helm_charts"
    nat           = "nat"
    bootstrap     = "cloud_apis"
  }
}
