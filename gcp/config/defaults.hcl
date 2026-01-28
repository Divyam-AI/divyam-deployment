#----------------------------------------------
# Default values for all Divyam GCP components
#
# This file provides default settings for GCP modules.
# Environment-specific configs override these defaults.
#----------------------------------------------
locals {
  env_name = get_env("ENV", "dev")

  # Default common variables
  common_vars = {
    environment           = local.env_name
    region                = "asia-south1"
    project_id            = get_env("GCP_PROJECT_ID", "")
    ci_cd_service_account = get_env("GCP_CI_CD_SERVICE_ACCOUNT", "")
  }

  derived_vars = {
    k8s_cluster_name = "divyam-gke-${local.env_name}-1-${local.common_vars.region}"
  }

  # Component configuration defaults
  cloud_apis = {
    enabled = true
    apis = [
      "compute.googleapis.com",
      "container.googleapis.com",
      "sql-component.googleapis.com",
      "artifactregistry.googleapis.com",
      "cloudbuild.googleapis.com",
      "iam.googleapis.com",
      "servicenetworking.googleapis.com",
      "dns.googleapis.com",
      "secretmanager.googleapis.com",
      "certificatemanager.googleapis.com",
      "networkmanagement.googleapis.com",
      "iap.googleapis.com",
    ]
  }

  shared_vpc = {
    enabled = false
  }

  bastion_host = {
    enabled = false
  }

  cloudsql = {
    enabled = false
  }

  secrets = {
    enabled = false
  }

  static_addr = {
    enabled = false
  }

  nat = {
    enabled = true
  }

  ssl_cert = {
    enabled = false
  }

  security = {
    enabled = false
  }

  gcs = {
    enabled = true
  }

  elb = {
    enabled = false
  }

  log_storage = {
    enabled        = true
    retention_days = 7
  }

  proxy_subnet = {
    enabled = false
  }

  gke = {
    enabled = true
  }

  iam_bindings = {
    enabled = true
  }

  cloud_build = {
    enabled = false
  }

  alerts = {
    enabled      = true
    exclude_list = []
  }

  notification_channels = {
    enabled = false
  }

  helm_charts = {
    enabled = true
  }

  shared_vpc_service_project = {
    enabled = false
  }

  # GCS remote state defaults
  gcs_remote_state = {
    bucket   = ""
    project  = ""
    location = "asia-south1"
  }
}
