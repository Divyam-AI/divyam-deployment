locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }

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
  name                = "${var.cluster.name}-agic-identity"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.cluster.name}-agic-identity"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

# Give the AKS Managed Identity "Contributor" role on the Application Gateway
resource "azurerm_role_assignment" "agic_appgw_access" {
  scope                = var.app_gateway_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id

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

# Giver read perms on the resource group
data "azurerm_resource_group" "selected" {
  name = var.resource_group_name
}

# Give identity assigned permissions
resource "azurerm_role_assignment" "agic_identity_assigner" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id

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

resource "azurerm_role_assignment" "resource_group_role" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id

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

# Allow AKS cluster's to have ingress join the app gw subnet.
resource "azurerm_role_assignment" "agic_subnet_permissions" {
  scope                = var.app_gateway_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_uami.principal_id

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

# ---------------------------
# AKS clusters
# ---------------------------
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.cluster.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster.dns_prefix

  kubernetes_version = var.cluster.kubernetes_version

  default_node_pool {
    name                 = "system"
    vnet_subnet_id       = var.subnet_ids[var.cluster.vnet_subnet_name]
    vm_size              = var.cluster.default_node_pool.vm_size
    node_count           = !var.cluster.default_node_pool.auto_scaling ? var.cluster.default_node_pool.count : null
    auto_scaling_enabled = var.cluster.default_node_pool.auto_scaling
    min_count            = var.cluster.default_node_pool.auto_scaling ? var.cluster.default_node_pool.min_count : null
    max_count            = var.cluster.default_node_pool.auto_scaling ? var.cluster.default_node_pool.max_count : null
    tags = merge(var.cluster.default_node_pool.tags, {
      for key, value in local.common_tags :
      key => templatestring(value, {
        resource_name  = "system"
        location       = var.location
        resource_group = var.resource_group_name
        environment    = var.environment
      })
    })

    node_labels                 = var.cluster.default_node_pool.node_labels
    temporary_name_for_rotation = var.cluster.default_node_pool.temporary_name_for_rotation
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agic_uami.id]
  }

  # Allows for use of Azure Key Vault
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  private_cluster_enabled = var.cluster.private_cluster_enabled
  dynamic "api_server_access_profile" {
    for_each = var.cluster.private_cluster_enabled ? [] : [1]
    content {
      authorized_ip_ranges = concat(
        # Add the application gateway public IP, else node pool creation fails
        # for public clusters.
        local.nat_gateway_cidr != null ? [local.nat_gateway_cidr] : [],
        values(var.subnet_prefixes),
        var.cluster.api_server_authorized_ip_ranges
      )
    }
  }

  network_profile {
    network_plugin = var.cluster.network_plugin
    network_policy = var.cluster.network_policy
    service_cidr   = var.cluster.service_cidr
    dns_service_ip = var.cluster.dns_service_ip
  }

  dynamic "oms_agent" {
    for_each = var.enable_log_collection ? { "enabled" = true } : {}

    content {
      log_analytics_workspace_id      = azurerm_log_analytics_workspace.log_analytics_workspace["enabled"].id
      msi_auth_for_monitoring_enabled = true
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.enable_metrics_collection ? { "enabled" = true } : {}
    content {}
  }

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.cluster.name
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
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
  for_each = var.cluster.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vnet_subnet_id        = var.subnet_ids[each.value.vnet_subnet_name != null ? each.value.vnet_subnet_name : var.cluster.vnet_subnet_name]
  vm_size               = each.value.vm_size
  gpu_driver            = each.value.gpu_driver
  node_count            = !each.value.auto_scaling ? each.value.count : null
  auto_scaling_enabled  = each.value.auto_scaling
  min_count             = each.value.auto_scaling ? each.value.min_count : null
  max_count             = each.value.auto_scaling ? each.value.max_count : null
  node_taints           = each.value.node_taints
  tags = merge(each.value.tags, {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = each.key
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  })

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
  for_each = var.enable_log_collection ? { "enabled" = true } : {}

  name                = "${var.cluster.name}-log-workspace"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.cluster.name}-log-workspace"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_monitor_data_collection_rule" "aks_logs" {
  for_each = var.enable_log_collection ? { "enabled" = true } : {}

  name                = "${var.cluster.name}-aks-dcr"
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    log_analytics {
      name                  = "law-destination"
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace["enabled"].id
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

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.cluster.name}-aks-dcr"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks_dcr_assoc" {
  for_each = var.enable_log_collection ? { "enabled" = true } : {}

  name                    = "${var.cluster.name}-aks-dcr-assoc"
  target_resource_id      = azurerm_kubernetes_cluster.aks_cluster.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_logs["enabled"].id
}

# ---------------------------
# Managed metrics collection
# ---------------------------
resource "azurerm_monitor_workspace" "prometheus" {
  for_each = var.enable_metrics_collection ? { "enabled" = true } : {}

  name                = "${join("", [for p in split("-", var.cluster.name) : substr(p, 0, 3)])}-amw"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${join("", [for p in split("-", var.cluster.name) : substr(p, 0, 3)])}-amw"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_monitor_data_collection_rule" "aks_prometheus" {
  for_each = var.enable_metrics_collection ? { "enabled" = true } : {}

  name                = "${var.cluster.name}-aks-prom-dcr"
  location            = var.location
  resource_group_name = var.resource_group_name

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
      #endpoint_name = "prometheus-metrics-ep"
    }
  }


  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["prometheus-dest"]
  }

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.cluster.name}-aks-prom-dcr"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks_assoc" {
  for_each = var.enable_metrics_collection ? { "enabled" = true } : {}

  name                    = "${var.cluster.name}-aks-prometheus-assoc"
  target_resource_id      = azurerm_kubernetes_cluster.aks_cluster.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_prometheus["enabled"].id
}


resource "azurerm_dashboard_grafana" "grafana" {
  for_each = var.enable_metrics_collection ? { "enabled" = true } : {}

  name                  = "${join("", [for p in split("-", var.cluster.name) : substr(p, 0, 3)])}-gf"
  resource_group_name   = var.resource_group_name
  location              = var.location
  grafana_major_version = 11

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus["enabled"].id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${join("", [for p in split("-", var.cluster.name) : substr(p, 0, 3)])}-gf"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_role_assignment" "grafana_reader" {
  for_each = var.enable_metrics_collection ? { "enabled" = true } : {}

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

# ---------------------------
# AGIC for App gateway -> AKS
# service connect
# ---------------------------
resource "azurerm_federated_identity_credential" "agic" {
  name                = "${var.cluster.name}-agic-fic"
  resource_group_name = azurerm_user_assigned_identity.agic_uami.resource_group_name
  parent_id           = azurerm_user_assigned_identity.agic_uami.id
  issuer              = azurerm_kubernetes_cluster.aks_cluster.oidc_issuer_url
  subject             = "system:serviceaccount:kube-system:${var.cluster.name}-ingress-azure"
  audience            = ["api://AzureADTokenExchange"]
}

provider "helm" {
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "agic" {
  name       = "${var.cluster.name}-ingress-azure"
  repository = "oci://mcr.microsoft.com/azure-application-gateway/charts/"
  chart      = "ingress-azure"
  namespace  = "kube-system"
  version    = var.agic_helm_version

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
