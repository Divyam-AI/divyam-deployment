# Define all resource names once; use them for both object creation and tag rendering so tags stay in sync.
locals {
  # Resource names (single source of truth for name + tags).
  cluster_name           = var.cluster.name
  default_node_pool_name = "system"
  log_workspace_name     = "${var.cluster.name}-log-workspace"
  aks_dcr_name           = "${var.cluster.name}-aks-dcr"
  amw_prefix             = join("", [for p in split("-", var.cluster.name) : substr(p, 0, 3)])
  amw_name               = "${local.amw_prefix}-amw"
  prom_dcr_name          = "${var.cluster.name}-prom-dcr"
  grafana_name           = "${local.amw_prefix}-gf"

  tag_context_base = merge(var.tag_globals, var.tag_context)

  # Rendered tags: resource_name comes from the names above so tags always match the resource name.
  rendered_tags_cluster      = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.cluster_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_system       = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.default_node_pool_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_log_workspace = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.log_workspace_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_aks_dcr       = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.aks_dcr_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_amw          = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.amw_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_prom_dcr     = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.prom_dcr_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_grafana      = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.grafana_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_for_pool     = { for pk in keys(var.cluster.additional_node_pools) : pk => { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = pk }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) } }

  log_streams = [
    "Microsoft-ContainerLog",
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
    "Microsoft-KubeNodeInventory",
    "Microsoft-KubePVInventory",
    "Microsoft-KubeServices",
    "Microsoft-KubeMonAgentEvents",
    "Microsoft-InsightsMetrics",
    "Microsoft-ContainerInventory",
    "Microsoft-ContainerNodeInventory",
    "Microsoft-Perf",
  ]

  # Optional: namespaces for log collection; from artifacts or empty when artifacts_path not set.
  namespaces = var.artifacts_path != null && var.artifacts_path != "" ? try(
    distinct([
      for chart in values(try(yamldecode(file(var.artifacts_path))["helm_charts"], {})) :
      lookup(chart, "namespace", null) != null ? chart["namespace"] : "${try(chart["namespace_prefix"], "app")}-${var.environment}-ns"
    ]),
    []
  ) : []

  dataCollectionSettings = {
    data_collection_interval                     = "1m"
    namespace_filtering_mode_for_data_collection = length(local.namespaces) > 0 ? "Include" : "Off"
    namespaces_for_data_collection               = local.namespaces
    container_log_v2_enabled                     = true
  }
}

# Look up VNet and subnets in Azure by name (from defaults.hcl vnet). Same pattern as 0-divyam_object_storage/azure.
data "azurerm_virtual_network" "vnet" {
  count               = length(var.vnet_subnet_names) > 0 ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "vnet_subnets" {
  for_each             = length(var.vnet_subnet_names) > 0 ? toset(var.vnet_subnet_names) : toset([])
  name                 = each.key
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

# Look up NAT gateway public IP by name (from defaults.hcl nat.nat_public_ip_name) when nat_gateway_ip not provided.
data "azurerm_public_ip" "nat_ip" {
  count               = (var.nat_gateway_ip == null || var.nat_gateway_ip == "") && var.nat_public_ip_name != null && var.nat_public_ip_name != "" ? 1 : 0
  name                = var.nat_public_ip_name
  resource_group_name = var.resource_group_name
}

# When create = false (and not forcing for import), fetch existing AKS cluster by name for outputs.
data "azurerm_kubernetes_cluster" "existing" {
  count               = (var.create) ? 0 : 1
  name                = local.cluster_name
  resource_group_name = var.resource_group_name
}

locals {
  aks_cluster = (var.create) ? azurerm_kubernetes_cluster.aks_cluster[0] : data.azurerm_kubernetes_cluster.existing[0]
}

locals {
  vnet_id         = length(var.vnet_subnet_names) > 0 ? data.azurerm_virtual_network.vnet[0].id : null
  subnet_ids       = length(var.vnet_subnet_names) > 0 ? { for n in var.vnet_subnet_names : n => data.azurerm_subnet.vnet_subnets[n].id } : {}
  subnet_names    = var.vnet_subnet_names
  subnet_prefixes = length(var.vnet_subnet_names) > 0 ? { for n in var.vnet_subnet_names : n => data.azurerm_subnet.vnet_subnets[n].address_prefixes[0] } : {}
  # K8s service/pod CIDRs from VNet fetched from cloud (by vnet name + resource group). cidrsubnet(space, 4, n) = /20 blocks; n=1,2,3 avoid node and app_gw subnets.
  vnet_address_space        = length(data.azurerm_virtual_network.vnet) > 0 ? data.azurerm_virtual_network.vnet[0].address_space[0] : null
  k8s_service_cidr_computed = local.vnet_address_space != null ? cidrsubnet(local.vnet_address_space, 4, 1) : null
  k8s_dns_service_ip_computed = local.k8s_service_cidr_computed != null ? cidrhost(local.k8s_service_cidr_computed, 10) : null
  service_cidr   = coalesce(try(var.cluster.service_cidr, null), local.k8s_service_cidr_computed, "10.1.0.0/16")
  dns_service_ip = coalesce(try(var.cluster.dns_service_ip, null), local.k8s_dns_service_ip_computed, "10.1.0.10")

  # Resolve NAT gateway IP: from variable or by looking up public IP by name (Azure API).
  resolved_nat_gateway_ip = coalesce(
    var.nat_gateway_ip,
    try(data.azurerm_public_ip.nat_ip[0].ip_address, null)
  )
  nat_gateway_cidr = local.resolved_nat_gateway_ip == null ? null : (
    strcontains(local.resolved_nat_gateway_ip, ":") ? "${local.resolved_nat_gateway_ip}/128" : "${local.resolved_nat_gateway_ip}/32"
  )
}

# ---------------------------
# AKS clusters
# ---------------------------
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  count               = var.create ? 1 : 0
  name                = local.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster.dns_prefix

  kubernetes_version = var.cluster.kubernetes_version

  automatic_upgrade_channel = var.cluster.automatic_channel_upgrade

  # Node Auto-Provisioning (NAP): when "Auto", AKS provisions workload nodes from pending pod requirements (no VM size needed for that capacity). Requires azurerm >= 4.57.
  dynamic "node_provisioning_profile" {
    for_each = var.cluster.node_provisioning_mode == "Auto" ? [1] : []
    content {
      mode = "Auto"
    }
  }

  default_node_pool {
    name                 = local.default_node_pool_name
    vnet_subnet_id       = local.subnet_ids[var.cluster.vnet_subnet_name]
    vm_size              = var.cluster.default_node_pool.vm_size
    node_count           = !var.cluster.default_node_pool.auto_scaling ? var.cluster.default_node_pool.count : null
    auto_scaling_enabled = var.cluster.default_node_pool.auto_scaling
    min_count            = var.cluster.default_node_pool.auto_scaling ? var.cluster.default_node_pool.min_count : null
    max_count            = var.cluster.default_node_pool.auto_scaling ? var.cluster.default_node_pool.max_count : null
    tags = merge(var.cluster.default_node_pool.tags, local.rendered_tags_system)

    node_labels                 = var.cluster.default_node_pool.node_labels
    temporary_name_for_rotation = var.cluster.default_node_pool.temporary_name_for_rotation
  }

  identity {
    type = "SystemAssigned"
  }

  # Allows for use of Azure Key Vault
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  private_cluster_enabled = var.cluster.private_cluster_enabled
  dynamic "api_server_access_profile" {
    for_each = var.cluster.private_cluster_enabled ? [] : [1]
    content {
      authorized_ip_ranges = concat(
        local.nat_gateway_cidr != null ? [local.nat_gateway_cidr] : [],
        values(local.subnet_prefixes),
        var.cluster.api_server_authorized_ip_ranges
      )
    }
  }

  network_profile {
    network_plugin = var.cluster.network_plugin
    network_policy = var.cluster.network_policy
    service_cidr   = local.service_cidr
    dns_service_ip = local.dns_service_ip
  }

  dynamic "oms_agent" {
    for_each = var.create && var.enable_log_collection ? { "enabled" = true } : {}

    content {
      log_analytics_workspace_id      = azurerm_log_analytics_workspace.log_analytics_workspace["enabled"].id
      msi_auth_for_monitoring_enabled = true
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.create && var.enable_metrics_collection ? { "enabled" = true } : {}
    content {}
  }

  tags = local.rendered_tags_cluster

  lifecycle {
    ignore_changes = [
      kubernetes_version,
      dns_prefix,
      default_node_pool[0].upgrade_settings
    ]
  }
}

# Additional node pool
resource "azurerm_kubernetes_cluster_node_pool" "additional_node_pools" {
  for_each = var.create ? var.cluster.additional_node_pools : {}

  name                  = each.key
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.aks_cluster[0].id
  vnet_subnet_id        = local.subnet_ids[each.value.vnet_subnet_name != null ? each.value.vnet_subnet_name : var.cluster.vnet_subnet_name]
  vm_size               = each.value.vm_size
  gpu_driver            = each.value.gpu_driver
  priority              = try(each.value.priority, "Regular")
  eviction_policy       = try(each.value.priority, "Regular") == "Spot" ? "Deallocate" : null
  node_count            = !each.value.auto_scaling ? each.value.count : null
  auto_scaling_enabled  = each.value.auto_scaling
  min_count             = each.value.auto_scaling ? each.value.min_count : null
  max_count             = each.value.auto_scaling ? each.value.max_count : null
  node_taints           = each.value.node_taints
  tags = merge(each.value.tags, local.rendered_tags_for_pool[each.key])

  node_labels = each.value.node_labels

  lifecycle {
    ignore_changes = [
      upgrade_settings
    ]
  }
}

# ---------------------------
# Container Logs collection
# ---------------------------
resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  for_each = var.create && var.enable_log_collection ? { "enabled" = true } : {}

  name                = local.log_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.logs_retention_days
  tags = local.rendered_tags_log_workspace
}

resource "azurerm_monitor_data_collection_rule" "aks_logs" {
  for_each = var.create && var.enable_log_collection ? { "enabled" = true } : {}

  name                = local.aks_dcr_name
  resource_group_name  = var.resource_group_name
  location             = var.location

  destinations {
    log_analytics {
      name                  = "law-destination"
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace["enabled"].id
    }
  }

  data_sources {
    syslog {
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7", "lpr", "mail", "news", "syslog", "user", "uucp"]
      log_levels     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "sysLogsDataSource"
    }

    extension {
      streams        = local.log_streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval                          = local.dataCollectionSettings.data_collection_interval
          namespaceFilteringMode            = local.dataCollectionSettings.namespace_filtering_mode_for_data_collection
          namespaces                         = local.dataCollectionSettings.namespaces_for_data_collection
          enableContainerLogV2               = true
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  data_flow {
    streams      = local.log_streams
    destinations = ["law-destination"]
  }

  tags = local.rendered_tags_aks_dcr
}

resource "azurerm_monitor_data_collection_rule_association" "aks_dcr_assoc" {
  for_each = var.create && var.enable_log_collection ? { "enabled" = true } : {}

  name                    = "${var.cluster.name}-aks-dcr-assoc"
  target_resource_id      = azurerm_kubernetes_cluster.aks_cluster[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_logs["enabled"].id
}

# ---------------------------
# Managed metrics collection
# ---------------------------
resource "azurerm_monitor_workspace" "prometheus" {
  for_each = var.create && var.enable_metrics_collection ? { "enabled" = true } : {}

  name                = local.amw_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = local.rendered_tags_amw
}

resource "azurerm_monitor_data_collection_rule" "aks_prometheus" {
  for_each = var.create && var.enable_metrics_collection ? { "enabled" = true } : {}

  name                = local.prom_dcr_name
  location             = var.location
  resource_group_name  = var.resource_group_name

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus["enabled"].id
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
  for_each = var.create && var.enable_metrics_collection ? { "enabled" = true } : {}

  name                    = "${var.cluster.name}-aks-prometheus-assoc"
  target_resource_id      = azurerm_kubernetes_cluster.aks_cluster[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_prometheus["enabled"].id
}

resource "azurerm_dashboard_grafana" "grafana" {
  for_each = var.create && var.enable_metrics_collection ? { "enabled" = true } : {}

  name                = local.grafana_name
  resource_group_name = var.resource_group_name
  location              = var.location
  grafana_major_version = 11

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus["enabled"].id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.rendered_tags_grafana
}

resource "azurerm_role_assignment" "grafana_reader" {
  for_each = var.create && var.enable_metrics_collection ? { "enabled" = true } : {}

  scope                = azurerm_monitor_workspace.prometheus["enabled"].id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.grafana["enabled"].identity[0].principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

