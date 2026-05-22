# Azure alerts: action group + Prometheus rule groups.
# Reads the neutral alert schema from 2-alerts/common/rules and translates to Azure-native
# Prometheus rule groups (azurerm_monitor_alert_prometheus_rule_group).
#
# Schema: see 2-alerts/common/rules/README.md.
# Severity is propagated as a label as-is.

locals {
  rule_files = fileset(var.rules_folder, "*.json")
  groups = {
    for f in local.rule_files :
    trimsuffix(basename(f), ".json") => jsondecode(file("${var.rules_folder}/${f}"))
  }

  # Convert Go-duration shorthand ("30s", "2m", "1h") to ISO-8601 ("PT30S", "PT2M", "PT1H").
  # Only supports a single unit suffix s|m|h. Combined values ("1h30m") are not supported.
  to_pt = {
    for f, g in local.groups : f => merge(
      {
        interval = "PT${upper(g.interval)}"
      },
      {
        rules = [
          for r in g.rules : merge(r, {
            for_iso          = "PT${upper(r.for)}"
            auto_resolve_iso = lookup(r, "auto_resolve", null) != null ? "PT${upper(r.auto_resolve)}" : null
          })
        ]
      }
    )
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
  for_each            = local.to_pt
  name                = replace(each.value.name, "_", "-")
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = var.azure_monitor_workspace_name
  description         = lookup(each.value, "description", each.value.name)
  rule_group_enabled  = lookup(each.value, "enabled", true)
  interval            = each.value.interval
  scopes              = [var.azure_monitor_workspace_id]

  dynamic "rule" {
    for_each = each.value.rules
    content {
      alert      = rule.value.alert
      expression = rule.value.expr
      for        = rule.value.for_iso
      enabled    = lookup(rule.value, "enabled", true)

      dynamic "alert_resolution" {
        for_each = rule.value.auto_resolve_iso != null ? [1] : []
        content {
          auto_resolved   = true
          time_to_resolve = rule.value.auto_resolve_iso
        }
      }

      labels = merge(
        {
          severity = rule.value.severity
        },
        lookup(rule.value, "labels", {})
      )

      annotations = {
        summary     = rule.value.annotations.summary
        description = rule.value.annotations.description
      }

      # Attach action group only for CRITICAL alerts (all configured webhooks fire).
      dynamic "action" {
        for_each = rule.value.severity == "CRITICAL" ? [1] : []
        content {
          action_group_id = azurerm_monitor_action_group.alerts.id
        }
      }
    }
  }

  tags = local.rendered_tags_rule_group[each.key]
}
