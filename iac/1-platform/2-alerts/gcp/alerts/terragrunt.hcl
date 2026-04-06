# GCP alerts. Config from values/defaults.hcl (alerts). Rules from 2-alerts/common/rules. Depends on 2-alerts/gcp/notification_channels.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "notification_channels" {
  config_path = "../notification_channels"
  mock_outputs = {
    notification_channel_email     = ""
    notification_channel_webhook   = ""
    notification_channel_google_chat = ""
    notification_channel_slack     = ""
  }
}

dependency "k8s" {
  config_path = "../../../1-k8s/gcp"
  skip_outputs = true
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/gcp/alerts"
}

locals {
  root        = include.root.locals.merged
  alerts_cfg  = try(local.root.alerts, {})
  project_id  = local.root.resource_scope.name
  cluster_id  = try(local.root.k8s.name, "${local.root.deployment_prefix}-k8s-cluster")
  rules_dir   = "${get_repo_root()}/1-platform/2-alerts/common/rules"
  rule_files  = fileset(local.rules_dir, "*.json")
  exclude     = try(local.alerts_cfg.exclude_list, [])
  # Load each rule JSON and replace {{project_id}} / {{cluster_id}}; filter by exclude_list
  rules = [
    for f in local.rule_files : (
      jsondecode(
        replace(
          replace(
            file("${local.rules_dir}/${f}"),
            "{{project_id}}", local.project_id
          ),
          "{{cluster_id}}", local.cluster_id
        )
      )
    )
    if !contains(local.exclude, jsondecode(file("${local.rules_dir}/${f}"))["name"])
  ]
}

inputs = merge(
  {
    enabled             = try(local.alerts_cfg.enabled, false)
    project_id          = local.project_id
    region              = local.root.region
    rules               = local.rules
    notification_channels = concat(
      try(local.alerts_cfg.notification_channels.email_enabled, false) ? [dependency.notification_channels.outputs.notification_channel_email] : [],
      try(local.alerts_cfg.notification_channels.pager_enabled, false) ? [dependency.notification_channels.outputs.notification_channel_webhook] : [],
      try(local.alerts_cfg.notification_channels.gchat_enabled, false) ? [dependency.notification_channels.outputs.notification_channel_google_chat] : [],
      try(local.alerts_cfg.notification_channels.slack_enabled, false) ? [dependency.notification_channels.outputs.notification_channel_slack] : []
    )
  }
)

exclude {
  if = !try(local.alerts_cfg.enabled, false)
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}