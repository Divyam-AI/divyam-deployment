#----------------------------------------------
# Global defaults shared across all cloud providers
#
# These settings are loaded first, then overridden by
# cloud-specific defaults and environment configs.
#----------------------------------------------
locals {
  # Common environment settings
  env_name = get_env("ENV", "dev")

  # Common tags applied to all resources across clouds
  common_tags = {
    Environment = "@{environment}"
    ManagedBy   = "terragrunt"
    Project     = "divyam"
  }

  # Helm charts common settings
  helm_charts = {
    enabled                        = true
    divyam_helm_registry_url       = "oci://asia-south1-docker.pkg.dev/prod-benchmarking/divyam-helm-dev-as1"
    divyam_docker_registry_url     = "asia-south1-docker.pkg.dev/prod-benchmarking/divyam-router-docker-as1"
    helm_release_replace_all       = true
    helm_release_recreate_pods_all = true
    helm_release_force_update_all  = true
    exclude_charts                 = []
  }

  # Alerts common settings
  alerts = {
    enabled      = true
    exclude_list = []
  }
}
