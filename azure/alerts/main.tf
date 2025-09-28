locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }

  # Load all JSON files
  alert_files = fileset(var.alerts_folder, "*.json")

  alerts = {
    for f in local.alert_files :
    trimsuffix(basename(f), ".json") => jsondecode(file("${var.alerts_folder}/${f}"))
  }
}

resource "azurerm_monitor_action_group" "alerts" {
  # TODO: Generate all prexies based on org and env centrally.
  name                = "${var.resource_name_prefix}-${var.environment}-alerts-action-group"
  resource_group_name = var.resource_group_name
  short_name          = "alerts"

  dynamic "email_receiver" {
    for_each = var.notification_email_alert_email == null ? [] : [var.notification_email_alert_email]
    content {
      name          = "email-alert"
      email_address = email_receiver.value
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.notification_pager_webhook_url == null ? [] : [var.notification_pager_webhook_url]
    content {
      name                    = "pager-webhook"
      service_uri             = webhook_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.notification_gchat_space_id == null ? [] : [var.notification_gchat_space_id]
    content {
      name                    = "gchat-webhook"
      service_uri             = "https://chat.googleapis.com/v1/spaces/${webhook_receiver.value}/messages"
      use_common_alert_schema = true
    }
  }

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.resource_name_prefix}-${var.environment}-alerts-action-group"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "alerts" {
  for_each            = local.alerts
  name                = replace(each.value.name, "_", "-")
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = var.azure_monitor_workspace_name
  description         = lookup(each.value, "display_name", each.value.name)
  rule_group_enabled = lookup(each.value, "enabled", true)

  # evaluation_interval in seconds → ISO8601 duration string
  interval = "PT${tonumber(replace(each.value.condition.evaluation_interval, "s", ""))}S"

  scopes = [var.azure_monitor_workspace_id]

  rule {
    alert = replace(each.value.display_name, " ", "")
    expression  = each.value.condition.query
    for   =  "PT${tonumber(replace(each.value.condition.duration, "s", ""))}S"

    labels = {
      severity   = each.value.severity
      rule_group = lookup(each.value.condition, "rule_group", "")
      alert_rule = lookup(each.value.condition, "alert_rule", "")
    }

    annotations = {
      summary     = each.value.condition.display_name
      description = "Generated from JSON spec"
    }

    dynamic "action" {
      for_each = contains(["CRITICAL"], each.value.severity) ? [1] : [] # condition here
      content {
        action_group_id = azurerm_monitor_action_group.alerts.id
      }
    }
  }

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = replace(each.value.name, "_", "-")
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}
