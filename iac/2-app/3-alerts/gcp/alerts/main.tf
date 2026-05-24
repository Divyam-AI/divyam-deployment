# GCP alerts: google_monitoring_alert_policy with condition_prometheus_query_language.
# Reads the neutral alert schema from 3-alerts/common/rules and translates per rule
# (one policy per rule). Notification channels are passed in by the parent module.
#
# Schema: see 3-alerts/common/rules/README.md.

locals {
  rule_files = fileset(var.rules_folder, "*.json")
  groups = {
    for f in local.rule_files :
    trimsuffix(basename(f), ".json") => jsondecode(file("${var.rules_folder}/${f}"))
  }

  # Flatten groups -> rules, attach group metadata, filter by exclude_list.
  rules = flatten([
    for gname, g in local.groups : [
      for r in g.rules : merge(r, {
        _group_name     = gname
        _group_interval = g.interval
      }) if !contains(var.exclude_list, r.alert)
    ]
  ])

  # Distinct duration strings used anywhere. compact() drops empty strings (for missing auto_resolve).
  _durations = distinct(compact(concat(
    [for r in local.rules : r.for],
    [for r in local.rules : r._group_interval],
    [for r in local.rules : try(r.auto_resolve, "")]
  )))

  # Go-duration shorthand (single unit) -> seconds-suffixed string.
  # "30s" -> "30s", "2m" -> "120s", "1h" -> "3600s".
  _seconds_map = {
    for d in local._durations :
    d => (
      can(regex("s$", d)) ? "${substr(d, 0, length(d) - 1)}s" :
      can(regex("m$", d)) ? "${tonumber(substr(d, 0, length(d) - 1)) * 60}s" :
      can(regex("h$", d)) ? "${tonumber(substr(d, 0, length(d) - 1)) * 3600}s" :
      d
    )
  }

  rules_with_durations = [
    for r in local.rules : merge(r, {
      _for_secs          = local._seconds_map[r.for]
      _interval_secs     = local._seconds_map[r._group_interval]
      _auto_resolve_secs = lookup(r, "auto_resolve", null) != null ? local._seconds_map[r.auto_resolve] : null
    })
  ]
}

resource "google_monitoring_alert_policy" "alerts" {
  for_each = var.enabled ? { for r in local.rules_with_durations : r.alert => r } : {}

  project      = var.project_id
  display_name = each.value.alert
  combiner     = "OR"
  severity     = each.value.severity
  enabled      = lookup(each.value, "enabled", true)

  documentation {
    content   = each.value.annotations.description
    mime_type = "text/markdown"
    subject   = each.value.annotations.summary
  }

  user_labels = merge(
    {
      rule_group = each.value._group_name
    },
    lookup(each.value, "labels", {})
  )

  conditions {
    display_name = "${each.value.annotations.summary} Condition"

    condition_prometheus_query_language {
      query               = each.value.expr
      duration            = each.value._for_secs
      evaluation_interval = each.value._interval_secs
      labels              = lookup(each.value, "labels", {})
      rule_group          = lookup(lookup(each.value, "labels", {}), "rule_group", each.value._group_name)
      alert_rule          = lookup(lookup(each.value, "labels", {}), "alert_rule", each.value.alert)
    }
  }

  dynamic "alert_strategy" {
    for_each = each.value._auto_resolve_secs != null ? [1] : []
    content {
      auto_close           = each.value._auto_resolve_secs
      notification_prompts = ["OPENED", "CLOSED"]
    }
  }

  # Attach channels only for CRITICAL alerts.
  notification_channels = each.value.severity == "CRITICAL" ? var.notification_channels : []
}
