# Datadog alerts: one datadog_monitor per rule that yields a Datadog query.
# Query rendering (structured IR or template) + metric-map resolution + normalization +
# {{cluster_name}}/{{env}}/{{window}}/{{threshold}} substitution are done by common/render;
# this module maps the rendered monitors onto datadog_monitor and applies the provider-specific
# knobs (priority, thresholds, paging handles, renotify / no-data).
#
# Schema: see ../common/rules/README.md.

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}/"
}

module "render" {
  source          = "../common/render"
  rules_folder    = var.rules_folder
  metric_map_file = var.metric_map_file
  cluster_name    = var.cluster_name
  env             = var.env
  exclude_list    = var.exclude_list
}

locals {
  # alert -> rule (merged: rendered `query` string + all neutral fields + datadog overrides).
  monitors = module.render.datadog_monitors

  severity_to_priority = {
    CRITICAL = 1
    WARNING  = 3
    INFO     = 5
  }

  # Effective thresholds: a per-rule datadog.thresholds override wins over neutral thresholds.
  # monitor_thresholds is only emitted for multi-tier monitors (a warning tier exists); count
  # monitors (`> 0`, critical-only) omit it, matching Datadog's rejection of recovery == critical.
  thresholds      = { for k, v in local.monitors : k => try(v.datadog.thresholds, v.thresholds, {}) }
  emit_thresholds = { for k, v in local.monitors : k => try(local.thresholds[k].warning, null) != null }

  # A monitor pages when it is CRITICAL, opts in via the neutral notification.notify (pages every
  # backend), or via the Datadog-only legacy datadog.notify (pages Datadog only).
  pages = { for k, v in local.monitors : k => (v.severity == "CRITICAL" || try(v.notification.notify, false) || try(v.datadog.notify, false)) }

  # Per-rule duration overrides (Go-duration shorthand) -> minutes, for renotify / no-data.
  _override_durs = distinct(compact(concat(
    [for k, v in local.monitors : try(v.notification.renotify_interval, "")],
    [for k, v in local.monitors : try(v.notification.no_data_timeframe, "")],
  )))
  _minutes_map = {
    for d in local._override_durs :
    d => (
      can(regex("h$", d)) ? tonumber(trimsuffix(d, "h")) * 60 :
      can(regex("m$", d)) ? tonumber(trimsuffix(d, "m")) :
      can(regex("s$", d)) ? tonumber(trimsuffix(d, "s")) / 60 :
      tonumber(d)
    )
  }

  # Message suffixes: runbook/dashboard links, then the pager @-handles (kept last).
  runbook_suffix = {
    for k, v in local.monitors : k => join("", concat(
      try(v.runbook_url, null) != null ? ["\n\nRunbook: ${v.runbook_url}"] : [],
      try(v.dashboard_url, null) != null ? ["\n\nDashboard: ${v.dashboard_url}"] : [],
    ))
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
  handles_suffix  = length(local.webhook_handles) > 0 ? "\n\n${join(" ", local.webhook_handles)}" : ""

  pager_suffix = { for k, v in local.monitors : k => (local.pages[k] && length(local.webhook_handles) > 0) ? local.handles_suffix : "" }
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
    for k, v in local.monitors : k => v
    if var.enabled
  }

  name  = each.value.alert
  type  = try(each.value.datadog.type, "metric alert")
  query = each.value.query

  priority = coalesce(try(each.value.notification.priority, null), lookup(local.severity_to_priority, each.value.severity, 3))

  message = "${try(each.value.datadog.message, each.value.description)}${local.runbook_suffix[each.key]}${local.pager_suffix[each.key]}"

  tags = concat(
    [
      "env:${var.env}",
      "cluster:${var.cluster_name}",
      "rule_group:${each.value.group_name}",
      "severity:${each.value.severity}",
      "managed-by:terraform",
    ],
    [for k, v in each.value.labels : "${k}:${v}"]
  )

  include_tags = true

  notify_no_data    = try(each.value.notification.notify_no_data, var.notify_no_data)
  no_data_timeframe = try(each.value.notification.notify_no_data, var.notify_no_data) ? try(local._minutes_map[each.value.notification.no_data_timeframe], var.no_data_timeframe) : null

  require_full_window = true

  renotify_interval = local.pages[each.key] ? try(local._minutes_map[each.value.notification.renotify_interval], var.renotify_interval) : 0
  renotify_statuses = local.pages[each.key] ? try(each.value.notification.renotify_statuses, var.renotify_statuses) : null

  dynamic "monitor_thresholds" {
    for_each = local.emit_thresholds[each.key] ? [local.thresholds[each.key]] : []
    content {
      # lookup() — JSON thresholds omit keys per rule (e.g. binary alerts have no warning tier).
      critical          = try(tonumber(lookup(monitor_thresholds.value, "critical", null)), null)
      warning           = try(tonumber(lookup(monitor_thresholds.value, "warning", null)), null)
      critical_recovery = try(tonumber(lookup(monitor_thresholds.value, "critical_recovery", null)), null)
      warning_recovery  = try(tonumber(lookup(monitor_thresholds.value, "warning_recovery", null)), null)
    }
  }
}
