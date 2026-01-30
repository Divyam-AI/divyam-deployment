#----------------------------------------------
# Preprod environment shared settings
# Settings that apply to both Azure and GCP in preprod
#----------------------------------------------
locals {
  environment = "preprod"

  common_tags = {
    Environment = "preprod"
  }

  # Helm charts settings shared across clouds
  helm_charts = {
    enabled = true
  }

  # Alerts settings shared across clouds
  alerts = {
    enabled      = true
    exclude_list = ["router_elb_5xx_errors", "superset_elb_5xx_errors"]
  }
}
