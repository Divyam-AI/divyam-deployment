locals {
  amw_prefix    = join("", [for p in split("-", var.cluster_name) : substr(p, 0, 3)])
  amw_name      = coalesce(var.azure_monitor_workspace_name, "${local.amw_prefix}-amw")
  prom_dcr_name = "${var.cluster_name}-prom-dcr"
  grafana_name  = "${local.amw_prefix}-gf"

  tag_context_base = merge(var.tag_globals, var.tag_context)

  rendered_tags_amw      = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.amw_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_prom_dcr = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.prom_dcr_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_grafana  = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.grafana_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }

  metrics_on       = var.enabled && var.enable_metrics_collection
  create_amw       = local.metrics_on && var.create_amw
  use_existing_amw = local.metrics_on && !var.create_amw

  amw_id = local.create_amw ? azurerm_monitor_workspace.prometheus["enabled"].id : (
    local.use_existing_amw ? data.azurerm_monitor_workspace.existing[0].id : null
  )
  amw_name_out = local.create_amw ? azurerm_monitor_workspace.prometheus["enabled"].name : (
    local.use_existing_amw ? data.azurerm_monitor_workspace.existing[0].name : null
  )

  has_cluster = var.aks_cluster_id != null && var.aks_cluster_id != ""
}

data "azurerm_monitor_workspace" "existing" {
  count               = local.use_existing_amw ? 1 : 0
  name                = var.azure_monitor_workspace_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_monitor_workspace" "prometheus" {
  for_each = local.create_amw ? { "enabled" = true } : {}

  name                = local.amw_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.rendered_tags_amw
}

resource "azurerm_monitor_data_collection_rule" "aks_prometheus" {
  for_each = local.metrics_on && local.has_cluster ? { "enabled" = true } : {}

  name                = local.prom_dcr_name
  location            = var.location
  resource_group_name = var.resource_group_name

  destinations {
    monitor_account {
      monitor_account_id = local.amw_id
      name               = "prometheus-dest"
    }
  }

  data_sources {
    prometheus_forwarder {
      name    = "prometheus-forwarder-metrics"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["prometheus-dest"]
  }

  tags = local.rendered_tags_prom_dcr
}

resource "azurerm_monitor_data_collection_rule_association" "aks_assoc" {
  for_each = local.metrics_on && local.has_cluster ? { "enabled" = true } : {}

  name                    = "${var.cluster_name}-aks-prometheus-assoc"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_prometheus["enabled"].id
}

resource "azurerm_dashboard_grafana" "grafana" {
  for_each = local.create_amw ? { "enabled" = true } : {}

  name                  = local.grafana_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  grafana_major_version = 11

  azure_monitor_workspace_integrations {
    resource_id = local.amw_id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.rendered_tags_grafana
}

resource "azurerm_role_assignment" "grafana_reader" {
  for_each = local.create_amw ? { "enabled" = true } : {}

  scope                = local.amw_id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.grafana["enabled"].identity[0].principal_id

  lifecycle {
    ignore_changes = [name, role_definition_name, principal_id, scope]
  }
}
