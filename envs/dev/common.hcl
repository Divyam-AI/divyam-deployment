#----------------------------------------------
# Dev environment shared settings
# Settings that apply to both Azure and GCP in dev
#----------------------------------------------
locals {
  environment = "dev"

  common_tags = {
    Environment = "dev"
  }

  # Helm charts settings shared across clouds
  helm_charts = {
    enabled = true
  }

  # Alerts settings shared across clouds
  alerts = {
    enabled      = true
    exclude_list = []
  }
}
