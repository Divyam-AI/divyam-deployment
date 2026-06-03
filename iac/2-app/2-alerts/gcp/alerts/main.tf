# GCP alerts: google_monitoring_alert_policy with condition_prometheus_query_language.
# Query rendering + multi-tier (warning/critical) expansion is done by the shared common/render
# module; this module only maps the rendered Prometheus rules onto alert policies (one per rule).
# Notification channels are passed in by the parent module.
#
# Schema: see ../../common/rules/README.md.

module "render" {
  source          = "../../common/render"
  rules_folder    = var.rules_folder
  metric_map_file = var.metric_map_file
  cluster_name    = var.cluster_name
  env             = var.env
  exclude_list    = var.exclude_list
}

locals {
  rules = module.render.prometheus_rules

  # Distinct duration strings used anywhere. compact() drops empty strings (missing auto_resolve/renotify).
  _durations = distinct(compact(concat(
    [for r in local.rules : r.for],
    [for r in local.rules : r.interval],
    [for r in local.rules : try(r.auto_resolve, "")],
    [for r in local.rules : try(r.renotify_interval, "")],
  )))

  # Go-duration shorthand (single unit) -> seconds-suffixed string. "30s"->"30s", "2m"->"120s", "1h"->"3600s".
  _seconds_map = {
    for d in local._durations :
    d => (
      can(regex("s$", d)) ? "${substr(d, 0, length(d) - 1)}s" :
      can(regex("m$", d)) ? "${tonumber(substr(d, 0, length(d) - 1)) * 60}s" :
      can(regex("h$", d)) ? "${tonumber(substr(d, 0, length(d) - 1)) * 3600}s" :
      d
    )
  }

  # Keyed by alert name — stable, plan-time-known identity for for_each (critical keeps the base
  # name; a warning tier is the net-new key "<alert>-warning").
  rules_by_alert = { for r in local.rules : r.alert => r }
}

resource "google_monitoring_alert_policy" "alerts" {
  for_each = var.enabled ? local.rules_by_alert : {}

  project      = var.project_id
  display_name = each.value.alert
  combiner     = "OR"
  severity     = each.value.severity
  enabled      = each.value.enabled && each.value.group_enabled

  documentation {
    content = join("", concat(
      [each.value.description],
      each.value.runbook_url != null ? ["\n\n**Runbook:** ${each.value.runbook_url}"] : [],
      each.value.dashboard_url != null ? ["\n\n**Dashboard:** ${each.value.dashboard_url}"] : [],
    ))
    mime_type = "text/markdown"
    subject   = each.value.summary
  }

  user_labels = each.value.labels

  conditions {
    display_name = "${each.value.summary} Condition"

    condition_prometheus_query_language {
      query               = each.value.expr
      duration            = local._seconds_map[each.value.for]
      evaluation_interval = local._seconds_map[each.value.interval]
      labels              = each.value.labels
      rule_group          = lookup(each.value.labels, "rule_group", each.value.group_name)
      alert_rule          = lookup(each.value.labels, "alert_rule", each.value.alert)
    }
  }

  # auto_close and/or renotify rate-limit (notification.renotify_interval is honored on GCP via
  # notification_rate_limit; not all backends support per-rule renotify).
  dynamic "alert_strategy" {
    for_each = (try(each.value.auto_resolve, null) != null || try(each.value.renotify_interval, null) != null) ? [1] : []
    content {
      auto_close = try(each.value.auto_resolve, null) != null ? local._seconds_map[each.value.auto_resolve] : null

      dynamic "notification_rate_limit" {
        for_each = try(each.value.renotify_interval, null) != null ? [1] : []
        content {
          period = local._seconds_map[each.value.renotify_interval]
        }
      }

      notification_prompts = try(each.value.auto_resolve, null) != null ? ["OPENED", "CLOSED"] : ["OPENED"]
    }
  }

  # Attach channels for CRITICAL alerts and for any rule that opts in via notification.notify.
  # A per-rule gcp.notification_channels override wins over the module default.
  notification_channels = (each.value.severity == "CRITICAL" || each.value.notify) ? (each.value.gcp_notification_channels != null ? each.value.gcp_notification_channels : var.notification_channels) : []
}
