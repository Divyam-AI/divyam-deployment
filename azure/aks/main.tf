locals {
  flattened_additional_node_pools = flatten([
    for cluster_name, cluster in var.clusters : [
      for pool_name, pool in cluster.additional_node_pools : {
        cluster_name = cluster_name
        pool_name    = pool_name
        pool         = pool
      }
    ]
  ])

  nat_gateway_cidr = var.nat_gateway_ip == null ? null : (
    strcontains(var.nat_gateway_ip, ":") ? "${var.nat_gateway_ip}/128" : "${var.nat_gateway_ip}/32"
  )

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
  "Microsoft-Perf"]

  artifacts_preprocessed = yamldecode(file(var.artifacts_path))


  filtered_charts = [
    # Filter out excluded charts.
    for chart_name, chart in local.artifacts_preprocessed["helm_charts"] :
    { chart_name = chart_name, chart = chart }
    if !(contains(var.exclude_charts, chart_name))
  ]

  # The chart information.
  charts = { for pair in local.filtered_charts : pair.chart_name => pair.chart }


  namespaces = toset([
    for chart in local.charts : (
      lookup(chart, "namespace", null) != null ? chart["namespace"] : "${chart["namespace_prefix"]}-${var.environment}-ns"
    )
  ])

  dataCollectionSettings = {
    data_collection_interval                     = "1m"
    namespace_filtering_mode_for_data_collection = "Off"
    namespaces_for_data_collection               = local.namespaces
    container_log_v2_enabled                     = true
  }
}

# ---------------------------
# AGIC access setup
# ---------------------------
resource "azurerm_user_assigned_identity" "agic_uami" {
  name                = "${keys(var.clusters)[0]}-agic-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Give the AKS Managed Identity "Contributor" role on the Application Gateway
resource "azurerm_role_assignment" "agic_appgw_access" {
  scope                = var.app_gateway_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id
}

# Giver read perms on the resource group
data "azurerm_resource_group" "selected" {
  name = var.resource_group_name
}

# Give identity assigned permissions
resource "azurerm_role_assignment" "agic_identity_assigner" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id
}

data "azurerm_application_gateway" "app_gw" {
  resource_group_name = var.resource_group_name
  name                = var.app_gateway_name
}

resource "azurerm_role_assignment" "resource_group_role" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id
}

# Allow AKS cluster's to have ingress join the app gw subnet.
resource "azurerm_role_assignment" "agic_subnet_permissions" {
  scope                = data.azurerm_application_gateway.app_gw.gateway_ip_configuration[0].subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id
}

# ---------------------------
# AKS clusters
# ---------------------------
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  for_each            = var.clusters
  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = each.value.dns_prefix

  kubernetes_version = each.value.kubernetes_version

  default_node_pool {
    name                        = "system"
    vnet_subnet_id              = var.subnet_ids[each.value.vnet_subnet_name]
    vm_size                     = each.value.default_node_pool.vm_size
    node_count                  = !each.value.default_node_pool.auto_scaling ? each.value.default_node_pool.count : null
    auto_scaling_enabled        = each.value.default_node_pool.auto_scaling
    min_count                   = each.value.default_node_pool.auto_scaling ? each.value.default_node_pool.min_count : null
    max_count                   = each.value.default_node_pool.auto_scaling ? each.value.default_node_pool.max_count : null
    tags                        = each.value.default_node_pool.tags
    node_labels                 = each.value.default_node_pool.node_labels
    temporary_name_for_rotation = each.value.default_node_pool.temporary_name_for_rotation
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agic_uami.id]
  }

  # Allows for use of Azure Key Vault
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  private_cluster_enabled = each.value.private_cluster_enabled
  dynamic "api_server_access_profile" {
    for_each = each.value.private_cluster_enabled ? [] : [1]
    content {
      authorized_ip_ranges = concat(
        # Add the application gateway public IP, else node pool creation fails
        # for public clusters.
        local.nat_gateway_cidr != null ? [local.nat_gateway_cidr] : [],
        values(var.subnet_prefixes),
        each.value.api_server_authorized_ip_ranges
      )
    }
  }

  network_profile {
    network_plugin = each.value.network_plugin
    network_policy = each.value.network_policy
    service_cidr   = each.value.service_cidr
    dns_service_ip = each.value.dns_service_ip
  }

  dynamic "oms_agent" {
    for_each = var.enable_log_collection ? [1] : []

    content {
      log_analytics_workspace_id      = azurerm_log_analytics_workspace.log_analytics_workspace[each.key].id
      msi_auth_for_monitoring_enabled = true
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.enable_metrics_collection ? [1] : []
    content {}
  }

  tags = {
    environment = var.environment
  }

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
  for_each = tomap({
    for pool in local.flattened_additional_node_pools : "${pool.pool_name}.${pool.cluster_name}" => pool
  })

  name                  = each.value.pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster[each.value.cluster_name].id
  vnet_subnet_id        = var.subnet_ids[var.clusters[each.value.cluster_name].vnet_subnet_name]
  vm_size               = each.value.pool.vm_size
  gpu_driver            = each.value.pool.gpu_driver
  node_count            = !each.value.pool.auto_scaling ? each.value.pool.count : null
  auto_scaling_enabled  = each.value.pool.auto_scaling
  min_count             = each.value.pool.auto_scaling ? each.value.pool.min_count : null
  max_count             = each.value.pool.auto_scaling ? each.value.pool.max_count : null
  node_taints           = each.value.pool.node_taints
  tags                  = each.value.pool.tags
  node_labels           = each.value.pool.node_labels

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
  for_each = var.enable_log_collection ? var.clusters : {}

  name                = "${each.key}-log-workspace"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
}

resource "azurerm_monitor_data_collection_rule" "aks_logs" {
  for_each = var.enable_log_collection ? var.clusters : {}

  name                = "${each.key}-aks-dcr"
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    log_analytics {
      name                  = "law-destination"
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace[each.key].id
    }
  }

  data_sources {
    syslog {
      streams = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0", "local1",
      "local2", "local3", "local4", "local5", "local6", "local7", "lpr", "mail", "news", "syslog", "user", "uucp"]
      log_levels = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name       = "sysLogsDataSource"
    }

    extension {
      streams        = local.log_streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : local.dataCollectionSettings.data_collection_interval,
          "namespaceFilteringMode" : local.dataCollectionSettings.namespace_filtering_mode_for_data_collection,
          "namespaces" : local.dataCollectionSettings.namespaces_for_data_collection
          "enableContainerLogV2" : true
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  data_flow {
    streams      = local.log_streams
    destinations = ["law-destination"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks_dcr_assoc" {
  for_each = var.enable_log_collection ? var.clusters : {}

  name                    = "${each.key}-aks-dcr-assoc"
  target_resource_id      = azurerm_kubernetes_cluster.aks_cluster[each.key].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_logs[each.key].id
}

# ---------------------------
# Managed metrics collection
# ---------------------------
resource "azurerm_monitor_workspace" "prometheus" {
  for_each = var.enable_metrics_collection ? var.clusters : {}

  name                = "${join("", [for p in split("-", each.key) : substr(p, 0, 3)])}-amw"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_monitor_data_collection_rule" "aks_prometheus" {
  for_each = var.enable_metrics_collection ? var.clusters : {}

  name                = "${each.key}-aks-prom-dcr"
  location            = var.location
  resource_group_name = var.resource_group_name

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus[each.key].id
      name               = "prometheus-dest"
    }
  }

  data_sources {
    prometheus_forwarder {
      name    = "prometheus-forwarder-metrics"
      streams = ["Microsoft-PrometheusMetrics"]
      #endpoint_name = "prometheus-metrics-ep"
    }
  }


  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["prometheus-dest"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks_assoc" {
  for_each = var.enable_metrics_collection ? var.clusters : {}

  name                    = "${each.key}-aks-prometheus-assoc"
  target_resource_id      = azurerm_kubernetes_cluster.aks_cluster[each.key].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_prometheus[each.key].id
}


resource "azurerm_dashboard_grafana" "grafana" {
  for_each = var.enable_metrics_collection ? var.clusters : {}

  name                  = "${join("", [for p in split("-", each.key) : substr(p, 0, 3)])}-gf"
  resource_group_name   = var.resource_group_name
  location              = var.location
  grafana_major_version = 11

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus[each.key].id
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "grafana_reader" {
  for_each = var.enable_metrics_collection ? var.clusters : {}

  scope                = azurerm_monitor_workspace.prometheus[each.key].id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.grafana[each.key].identity[0].principal_id
}

# ---------------------------
# AGIC for App gateway -> AKS
# service connect
# ---------------------------
resource "azurerm_federated_identity_credential" "agic" {
  for_each            = var.clusters
  name                = "${each.key}-agic-fic"
  resource_group_name = azurerm_user_assigned_identity.agic_uami.resource_group_name
  parent_id           = azurerm_user_assigned_identity.agic_uami.id
  issuer              = azurerm_kubernetes_cluster.aks_cluster[each.key].oidc_issuer_url
  subject             = "system:serviceaccount:kube-system:${each.key}-ingress-azure"
  audience            = ["api://AzureADTokenExchange"]
}

provider "helm" {
  # TODO: First cluster.. maybe we should just generate one aks cluster per helm chart.. will simplify
  kubernetes = {
    host                   = values(azurerm_kubernetes_cluster.aks_cluster)[0].kube_config[0].host
    client_certificate     = base64decode(values(azurerm_kubernetes_cluster.aks_cluster)[0].kube_config[0].client_certificate)
    client_key             = base64decode(values(azurerm_kubernetes_cluster.aks_cluster)[0].kube_config[0].client_key)
    cluster_ca_certificate = base64decode(values(azurerm_kubernetes_cluster.aks_cluster)[0].kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "agic" {
  name       = "${keys(var.clusters)[0]}-ingress-azure"
  repository = "oci://mcr.microsoft.com/azure-application-gateway/charts/"
  chart      = "ingress-azure"
  namespace  = "kube-system"
  version    = "1.8.1"

  replace = true

  set = [
    {
      name  = "appgw.resourceGroup"
      value = var.resource_group_name
    },
    {
      name  = "appgw.name"
      value = var.app_gateway_name
    },
    {
      name  = "armAuth.type"
      value = "workloadIdentity"
    },
    {
      name  = "armAuth.identityResourceID"
      value = azurerm_user_assigned_identity.agic_uami.id
    },
    {
      name  = "armAuth.identityClientID"
      value = azurerm_user_assigned_identity.agic_uami.client_id
    },
    {
      name  = "rbac.enabled"
      value = "true"
    },
    {
      name  = "verbosityLevel"
      value = "3"
    }
  ]
}
