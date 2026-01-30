include "root" {
  path   = find_in_parent_folders("root.hcl", "gcp/root.hcl")
  expose = true
}

dependency "notification_channels" {
  config_path  = "../notification_channels"
  mock_outputs = {
    notification_channel_email       = ""
    notification_channel_webhook     = ""
    notification_channel_google_chat = ""
  }
}

dependency "gke" {
  config_path  = "../gke"
  mock_outputs = {
    cluster_endpoints       = {}
    cluster_ca_certificates = {}
  }
}

terraform {
  # Point to the Terraform code that wraps your Helm chart deployment.
  # (This might be a module using the Helm provider.)
  source = "../alerts"
}

locals {
  notification_channels = []
  base_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.derived_vars,
    include.root.locals.install_config.alerts
  )

  rule_files = fileset("${get_terragrunt_dir()}/rules", "*.json")

  rules = [
    for file in local.rule_files : (
      yamldecode(
          replace(
            replace(
              file("${get_terragrunt_dir()}/rules/${file}"),
              "{{project_id}}", local.base_inputs.project_id
            ),
            "{{cluster_id}}", local.base_inputs.k8s_cluster_name
          )
      )
    )
    if !contains(
      local.base_inputs.exclude_list,
      yamldecode(
        file("${get_terragrunt_dir()}/rules/${file}")
      )["name"]
    )
  ]

}

inputs = merge(
  local.base_inputs,
  {
    notification_channels = concat(
      local.notification_channels,
      include.root.locals.install_config.notification_channels.email_enabled
        ? [dependency.notification_channels.outputs.notification_channel_email]
        : [],
      include.root.locals.install_config.notification_channels.pager_enabled
        ? [dependency.notification_channels.outputs.notification_channel_webhook]
        : [],
      include.root.locals.install_config.notification_channels.gchat_enabled
        ? [lookup(dependency.notification_channels.outputs, "notification_channel_google_chat", null)]
        : []
    ),
    rules = local.rules
  }
)

skip = !local.base_inputs.enabled