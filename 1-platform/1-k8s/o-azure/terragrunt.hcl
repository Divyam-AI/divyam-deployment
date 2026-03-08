# AKS cluster (1-platform). Uses k8s config from values/defaults.hcl and values/azure/defaults.hcl (k8s_aks).
# VNet info is read from merged config (like 0-divyam_object_storage/azure); module looks up vnet/subnets in Azure by name.
# Depends on: 1-old/app_gw (AGIC), 1-old/nat (optional).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "app_gw" {
  config_path = "../../0-app_gw/azure"

  mock_outputs = {
    app_gateway_name        = "mock-app-gateway"
    app_gateway_id          = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/applicationGateways/mock"
    agic_identity_id       = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock"
    agic_identity_client_id = "mock-agic-client-id"
    gateway_subnet_id      = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
  }
}

dependency "nat" {
  config_path = "../../../1-old/nat"

  mock_outputs = {
    nat_gateway_enabled = false
    nat_gateway_ip      = null
  }
}

locals {
  root   = include.root.locals.merged
  k8s    = local.root.k8s
  k8s_aks = try(local.root.k8s_aks, {})
  # Cluster name from defaults.hcl k8s.name; dns_prefix defaults to cluster name.
  cluster_name = local.k8s.name
  dns_prefix   = try(local.k8s_aks.dns_prefix, null) != null ? local.k8s_aks.dns_prefix : local.k8s.name
  # AKS node subnet from vnet.subnet (single object with .name).
  vnet_subnet_name = local.root.vnet.subnet.name

  # VNet lookup inputs: vnet.subnet and vnet.app_gw_subnet are single objects with .name.
  vnet_name                 = local.root.vnet.name
  vnet_resource_group_name  = local.root.vnet.scope_name
  vnet_subnet_names         = [local.root.vnet.subnet.name, local.root.vnet.app_gw_subnet.name]
  app_gateway_subnet_name   = local.root.vnet.app_gw_subnet.name

  cluster = {
    name                            = local.cluster_name
    dns_prefix                      = local.dns_prefix
    kubernetes_version              = try(local.k8s_aks.kubernetes_version, "1.28")
    api_server_authorized_ip_ranges = try(local.k8s_aks.api_server_authorized_ip_ranges, [])
    private_cluster_enabled         = try(local.k8s_aks.private_cluster_enabled, true)
    vnet_subnet_name                = local.vnet_subnet_name

    network_plugin = try(local.k8s_aks.network_plugin, "azure")
    network_policy = try(local.k8s_aks.network_policy, "azure")
    dns_service_ip = try(local.k8s_aks.dns_service_ip, "10.1.0.10")
    service_cidr   = try(local.k8s_aks.service_cidr, "10.1.0.0/16")

    default_node_pool    = try(local.k8s_aks.default_node_pool, { vm_size = "Standard_D4s_v3", auto_scaling = true, min_count = 1, max_count = 5, count = null, tags = {}, node_labels = {}, temporary_name_for_rotation = "tempnp01" })
    additional_node_pools = try(local.k8s_aks.additional_node_pools, {})
  }
}

inputs = {
  location             = local.root.region
  resource_group_name  = local.root.resource_scope.name
  environment         = local.root.env_name
  common_tags         = try(local.root.common_tags, {})
  tag_globals         = try(include.root.inputs.tag_globals, {})
  tag_context         = try(include.root.inputs.tag_context, { resource_name = local.k8s.name })

  cluster = local.cluster

  vnet_name                 = local.vnet_name
  vnet_resource_group_name  = local.vnet_resource_group_name
  vnet_subnet_names         = local.vnet_subnet_names
  app_gateway_subnet_name   = local.app_gateway_subnet_name
  app_gateway_name          = dependency.app_gw.outputs.app_gateway_name
  app_gateway_id            = dependency.app_gw.outputs.app_gateway_id
  nat_gateway_ip            = dependency.nat.outputs.nat_gateway_enabled ? dependency.nat.outputs.nat_gateway_ip : null

  enable_log_collection    = try(local.k8s_aks.enable_log_collection, true)
  enable_metrics_collection = try(local.k8s_aks.enable_metrics_collection, true)
  agic_helm_version        = try(local.k8s_aks.agic_helm_version, "1.7.0")
  artifacts_path           = try(local.root.helm_charts.artifacts_path, null)
}

skip = !try(local.k8s.create, false)
