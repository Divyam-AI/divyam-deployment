#----------------------------------------------
# Prod environment shared settings
# Settings that apply to both Azure and GCP in prod
#----------------------------------------------
locals {
  environment = "prod"

  common_tags = {
    Environment = "production"
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
