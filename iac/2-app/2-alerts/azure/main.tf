# Azure alerts: action group + Prometheus rule groups.
# Query rendering + multi-tier (warning/critical) expansion is done by the shared common/render
# module; this module groups the rendered rules back by rule group and maps them onto
# azurerm_monitor_alert_prometheus_rule_group. Severity is propagated as a label as-is.
#
# Schema: see common/rules/README.md.

module "render" {
  source          = "../common/render"
  rules_folder    = var.rules_folder
  metric_map_file = var.metric_map_file
  cluster_name    = var.cluster_name
  env             = var.environment
  exclude_list    = var.exclude_list
}

locals {
  rules = module.render.prometheus_rules

  # Re-group the flat rendered rules by rule group. The for_each key is the file basename
  # (group_name, e.g. "k8s") — stable across edits; the resource `name` attribute is the group's
  # JSON `name` (group_title, e.g. "kubernetes"), preserving the existing resource identity.
  group_names = distinct([for r in local.rules : r.group_name])
  groups = {
    for gname in local.group_names : gname => {
      title       = [for r in local.rules : r.group_title if r.group_name == gname][0]
      description = [for r in local.rules : r.group_description if r.group_name == gname][0]
      interval    = [for r in local.rules : r.interval if r.group_name == gname][0]
      enabled     = [for r in local.rules : r.group_enabled if r.group_name == gname][0]
      rules       = [for r in local.rules : r if r.group_name == gname]
    }
  }

  tag_context_base  = merge(var.tag_globals, var.tag_context)
  action_group_name = "${var.resource_name_prefix}-alerts-action-group"
  rendered_tags_action_group = {
    for k, v in var.common_tags :
    k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.action_group_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), ""))
  }
  rendered_tags_rule_group = {
    for name, _ in local.groups :
    name => {
      for k, v in var.common_tags :
      k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = replace(name, "_", "-") }), try(regex("#\\{([^}]+)\\}", v)[0], ""), ""))
    }
  }
}

resource "azurerm_monitor_action_group" "alerts" {
  name                = local.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = "alerts"

  dynamic "webhook_receiver" {
    # Build {name -> url}; non-empty URLs only. for_each requires a map for stable keys.
    for_each = {
      for idx, url in var.webhook_urls : "webhook-${idx}" => url
      if url != null && url != ""
    }
    content {
      name                    = webhook_receiver.key
      service_uri             = webhook_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = local.rendered_tags_action_group
}

resource "azurerm_monitor_alert_prometheus_rule_group" "alerts" {
  for_each            = local.groups
  name                = replace(each.value.title, "_", "-")
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = data.azurerm_monitor_workspace.prometheus.name
  description         = each.value.description
  rule_group_enabled  = each.value.enabled
  interval            = "PT${upper(each.value.interval)}"
  scopes              = [data.azurerm_monitor_workspace.prometheus.id]

  dynamic "rule" {
    for_each = each.value.rules
    content {
      alert      = rule.value.alert
      expression = rule.value.expr
      for        = "PT${upper(rule.value.for)}"
      enabled    = rule.value.enabled && rule.value.group_enabled

      dynamic "alert_resolution" {
        for_each = try(rule.value.auto_resolve, null) != null ? [1] : []
        content {
          auto_resolved   = true
          time_to_resolve = "PT${upper(rule.value.auto_resolve)}"
        }
      }

      labels = merge(
        {
          severity = rule.value.severity
        },
        rule.value.labels
      )

      # Drop null runbook/dashboard via a filtered map comprehension (avoids ternary type mismatch).
      annotations = merge(
        {
          summary     = rule.value.summary
          description = rule.value.description
        },
        { for k, v in { runbook_url = rule.value.runbook_url, dashboard_url = rule.value.dashboard_url } : k => v if v != null }
      )

      # Attach action group for CRITICAL alerts and any rule that opts in via notification.notify.
      dynamic "action" {
        for_each = (rule.value.severity == "CRITICAL" || rule.value.notify) ? [1] : []
        content {
          action_group_id = azurerm_monitor_action_group.alerts.id
        }
      }
    }
  }

  tags = local.rendered_tags_rule_group[each.key]
}
