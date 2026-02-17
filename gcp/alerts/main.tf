provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_monitoring_alert_policy" "prometheus_alerts" {
  for_each = var.enabled ? { for rule in var.rules : rule.name => rule } : {}

  display_name = each.value.display_name
  combiner     = each.value.combiner
  severity     = each.value.severity

  conditions {
    display_name = each.value.condition.display_name
    condition_prometheus_query_language {
      query               = each.value.condition.query
      duration            = each.value.condition.duration
      evaluation_interval = each.value.condition.evaluation_interval
      alert_rule          = lookup(each.value.condition, "alert_rule", null)
      rule_group          = lookup(each.value.condition, "rule_group", null)
    }
  }

  alert_strategy {
    auto_close           = each.value.alert_strategy.auto_close
    notification_prompts = each.value.alert_strategy.notification_prompts
  }

  notification_channels = var.notification_channels

  user_labels = {
    created_by = "terraform"
  }
}
