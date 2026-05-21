# Datadog alerts: one datadog_monitor per rule that supplies a `datadog` block.
# Reads the neutral alert schema from 2-alerts/common/rules and translates per rule.
#
# Schema: see 2-alerts/common/rules/README.md.
#
# Datadog monitors do not speak PromQL natively; each rule must include a `datadog.query`
# in the Datadog monitor query DSL. Rules without a `datadog` block are skipped here.
#
# Webhooks: every URL in var.webhook_urls is registered as a Datadog webhook
# integration and referenced as @webhook-<name> on CRITICAL alert messages.
#
# Provider requirements are declared in zz_providers_override.tf (override file) to
# coexist with the terraform {} block that root.hcl generates in provider.tf.

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

  # Flatten + keep only rules that have a non-empty datadog.query.
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

  # Severity -> Datadog priority (1 = highest, 5 = lowest).
  severity_to_priority = {
    CRITICAL = 1
    WARNING  = 3
    INFO     = 5
  }

  # Webhook integrations to register. Map keeps stable resource keys.
  webhook_integrations = {
    for idx, url in var.webhook_urls : "${var.webhook_name_prefix}-${idx}" => url
    if url != null && url != ""
  }

  # Zenduty-style default webhook body (Datadog template variables — see integrations/webhooks docs).
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

  # All @-handles for CRITICAL monitors: one per registered webhook integration.
  webhook_handles         = [for name, _ in local.webhook_integrations : "@webhook-${name}"]
  critical_handles_suffix = length(local.webhook_handles) > 0 ? "\n\n${join(" ", local.webhook_handles)}" : ""

  monitors = {
    for r in local.rules : r.alert => merge(r, {
      _priority = lookup(local.severity_to_priority, r.severity, 3)
      _suffix   = r.severity == "CRITICAL" ? local.critical_handles_suffix : ""
      _message  = "${try(r.datadog.message, r.annotations.description)}${r.severity == "CRITICAL" ? local.critical_handles_suffix : ""}"
      _type     = try(r.datadog.type, "metric alert")
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
  query    = each.value.datadog.query
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

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  renotify_interval   = each.value.severity == "CRITICAL" ? 30 : 0

  depends_on = [datadog_webhook.pager]
}
