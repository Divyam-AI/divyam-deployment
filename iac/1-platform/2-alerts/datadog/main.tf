# Datadog alerts: one datadog_monitor per rule that supplies a `datadog` block.
# Reads the neutral alert schema from 2-alerts/common/rules and translates per rule.
#
# Schema: see 2-alerts/common/rules/README.md.
#
# Query placeholders: {{cluster_name}} is replaced with var.cluster_name at apply time.
# Thresholds live in rules[].datadog.thresholds (warning / critical / recovery) — not in the query string.

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}/"
}

locals {
  rule_files = fileset(var.rules_folder, "*.json")
  groups = {
    for f in local.rule_files :
    trimsuffix(basename(f), ".json") => jsondecode(file("${var.rules_folder}/${f}"))
  }

  rules = flatten([
    for gname, g in local.groups : [
      for r in g.rules : merge(r, {
        _group_name = gname
      })
      if !contains(var.exclude_list, r.alert)
      && lookup(r, "datadog", null) != null
      && try(r.datadog.query, "") != ""
    ]
  ])

  # Map keyed by alert name (static at plan time). Do not pre-merge computed monitor fields here —
  # that can make for_each values unknown when paired with depends_on on datadog_webhook.
  rules_by_alert = {
    for r in local.rules : r.alert => r
  }

  severity_to_priority = {
    CRITICAL = 1
    WARNING  = 3
    INFO     = 5
  }

  webhook_integrations = {
    for idx, url in var.webhook_urls : "${var.webhook_name_prefix}-${idx}" => url
    if url != null && url != ""
  }

  default_webhook_payload = {
    alert_id         = "$ALERT_ID"
    hostname         = "$HOSTNAME"
    date_posix       = "$DATE_POSIX"
    aggreg_key       = "$AGGREG_KEY"
    title            = "$EVENT_TITLE"
    alert_status     = "$ALERT_STATUS"
    alert_transition = "$ALERT_TRANSITION"
    link             = "$LINK"
    event_msg        = "$TEXT_ONLY_MSG"
  }

  webhook_payload = var.webhook_custom_payload != null ? var.webhook_custom_payload : local.default_webhook_payload

  webhook_handles = [for name, _ in local.webhook_integrations : "@webhook-${name}"]
  handles_suffix    = length(local.webhook_handles) > 0 ? "\n\n${join(" ", local.webhook_handles)}" : ""
}

resource "datadog_webhook" "pager" {
  for_each = {
    for k, v in local.webhook_integrations : k => v
    if var.enabled
  }

  name      = each.key
  url       = each.value
  encode_as = var.webhook_custom_payload_enabled ? "json" : null
  payload   = var.webhook_custom_payload_enabled ? jsonencode(local.webhook_payload) : null
}

resource "datadog_monitor" "alerts" {
  for_each = {
    for k, v in local.rules_by_alert : k => v
    if var.enabled
  }

  name  = each.value.alert
  type  = try(each.value.datadog.type, "metric alert")
  query = replace(each.value.datadog.query, "{{cluster_name}}", var.cluster_name)

  priority = lookup(local.severity_to_priority, each.value.severity, 3)

  message = "${try(each.value.datadog.message, each.value.annotations.description)}${(
    (each.value.severity == "CRITICAL" || try(each.value.datadog.notify, false)) && length(local.webhook_handles) > 0
  ) ? local.handles_suffix : ""}"

  tags = concat(
    [
      "env:${var.env}",
      "cluster:${var.cluster_name}",
      "rule_group:${each.value._group_name}",
      "severity:${each.value.severity}",
      "managed-by:terraform",
    ],
    [for k, v in lookup(each.value, "labels", {}) : "${k}:${v}"]
  )

  include_tags = true

  notify_no_data    = var.notify_no_data
  no_data_timeframe = var.notify_no_data ? var.no_data_timeframe : null

  require_full_window = true

  renotify_interval = contains(["CRITICAL", "WARNING"], each.value.severity) ? var.renotify_interval : 0
  renotify_statuses = contains(["CRITICAL", "WARNING"], each.value.severity) ? var.renotify_statuses : null

  dynamic "monitor_thresholds" {
    for_each = length(lookup(each.value.datadog, "thresholds", {})) > 0 ? [lookup(each.value.datadog, "thresholds", {})] : []
    content {
      # lookup() — JSON thresholds omit keys per rule (e.g. binary alerts have no warning tier).
      critical          = try(tonumber(lookup(monitor_thresholds.value, "critical", null)), null)
      warning           = try(tonumber(lookup(monitor_thresholds.value, "warning", null)), null)
      critical_recovery = try(tonumber(lookup(monitor_thresholds.value, "critical_recovery", null)), null)
      warning_recovery  = try(tonumber(lookup(monitor_thresholds.value, "warning_recovery", null)), null)
    }
  }
}
