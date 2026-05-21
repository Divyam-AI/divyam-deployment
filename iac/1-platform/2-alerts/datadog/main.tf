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

  monitors = {
    for r in local.rules : r.alert => merge(r, {
      _priority = lookup(local.severity_to_priority, r.severity, 3)
      _type     = try(r.datadog.type, "metric alert")
      _query = replace(
        r.datadog.query,
        "{{cluster_name}}",
        var.cluster_name
      )
      _thresholds = lookup(r.datadog, "thresholds", {})
      # Page on CRITICAL always; WARNING when datadog.notify = true (e.g. pvc-usage-high).
      _notify = r.severity == "CRITICAL" || try(r.datadog.notify, false)
      _message = "${try(r.datadog.message, r.annotations.description)}${(
        (r.severity == "CRITICAL" || try(r.datadog.notify, false)) && length(local.webhook_handles) > 0
      ) ? local.handles_suffix : ""}"
    })
  }
}

resource "datadog_webhook" "pager" {
  for_each = var.enabled ? local.webhook_integrations : {}

  name      = each.key
  url       = each.value
  encode_as = var.webhook_custom_payload_enabled ? "json" : null
  payload   = var.webhook_custom_payload_enabled ? jsonencode(local.webhook_payload) : null
}

resource "datadog_monitor" "alerts" {
  for_each = var.enabled ? local.monitors : {}

  name     = each.value.alert
  type     = each.value._type
  query    = each.value._query
  message  = each.value._message
  priority = each.value._priority

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

  renotify_interval = each.value._notify ? var.renotify_interval : 0
  renotify_statuses = each.value._notify ? var.renotify_statuses : null

  dynamic "monitor_thresholds" {
    for_each = length(each.value._thresholds) > 0 ? [each.value._thresholds] : []
    content {
      critical          = try(monitor_thresholds.value.critical, null)
      warning           = try(monitor_thresholds.value.warning, null)
      critical_recovery = try(monitor_thresholds.value.critical_recovery, null)
      warning_recovery  = try(monitor_thresholds.value.warning_recovery, null)
    }
  }

  depends_on = [datadog_webhook.pager]
}
