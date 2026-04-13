# AKS cluster (1-platform). Config from values/defaults.hcl k8s (k8s.aks when CLOUD_PROVIDER=azure).
# VNet info from merged config; NAT from values (nat_public_ip_name lookup in-module).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

locals {
  root    = include.root.locals.merged
  k8s     = local.root.k8s
  net     = try(local.k8s.network, {})
  pools   = try(local.k8s.node_pools, {})
  obs     = try(local.k8s.observability, {})

  cluster_name = local.k8s.name
  dns_prefix   = local.k8s.name
  vnet_subnet_name = local.root.vnet.subnet.name

  vnet_name                = local.root.vnet.name
  vnet_resource_group_name = local.root.vnet.scope_name
  vnet_subnet_names        = [local.root.vnet.subnet.name]

  cluster = {
    name                            = local.cluster_name
    dns_prefix                      = local.dns_prefix
    kubernetes_version               = try(local.k8s.kubernetes_version, "1.28")
    api_server_authorized_ip_ranges = try(local.k8s.api_server_authorized_ip_ranges, [])
    private_cluster_enabled         = true
    vnet_subnet_name                = local.vnet_subnet_name

    network_plugin = "azure"
    network_policy = "azure"
    # service_cidr and dns_service_ip are computed in Terraform from VNet fetched by name from Azure (data source).
    dns_service_ip = null
    service_cidr   = null

    node_provisioning_mode = try(local.k8s.node_provisioning_mode, "Manual")

    automatic_channel_upgrade = try(local.k8s.release_channel, "stable")

    default_node_pool = merge(try(local.pools.default, {}), {
      vm_size                     = try(local.pools.default.instance_type, "Standard_D4s_v3")
      temporary_name_for_rotation = "tempnp01"
      tags                        = {}
      node_labels                 = {}
    })
    # Resolve vm_size from instance_type (single value per cloud from defaults ternary) or legacy vm_size.
    # AKS: default node pool cannot be Spot; only additional pools support priority = "Spot".
    additional_node_pools = { for name, pool in try(local.pools.additional, {}) : name => {
      vm_size          = try(pool.instance_type, pool.vm_size, "Standard_D4s_v3")
      gpu_driver       = try(pool.gpu_driver, null)
      priority         = try(pool.spot_instance, false) ? "Spot" : "Regular"
      auto_scaling     = try(pool.auto_scaling, false)
      count            = try(pool.count, null)
      min_count        = try(pool.min_count, null)
      max_count        = try(pool.max_count, null)
      mode             = try(pool.mode, "User")
      node_taints      = try(pool.node_taints, [])
      tags             = try(pool.tags, {})
      node_labels      = try(pool.node_labels, {})
      vnet_subnet_name = try(pool.vnet_subnet_name, null)
    } }
  }
}

inputs = {
  location             = local.root.region
  resource_group_name  = local.root.resource_scope.name
  environment         = local.root.env_name
  create              = local.k8s.create
  common_tags         = try(local.root.common_tags, {})
  tag_globals         = try(include.root.inputs.tag_globals, {})
  tag_context         = { resource_name = local.k8s.name }

  cluster = local.cluster

  vnet_name                 = local.vnet_name
  vnet_resource_group_name  = local.vnet_resource_group_name
  vnet_subnet_names         = local.vnet_subnet_names
  # NAT IP: from values (optional override) or resolved in-module via data source using nat_public_ip_name.
  nat_gateway_ip          = try(local.root.nat.nat_gateway_ip, null)
  nat_public_ip_name      = try(local.root.nat.nat_public_ip_name, null)
  nat_resource_group_name = try(local.root.nat.nat_resource_group_name, null)

  enable_log_collection    = try(local.obs.enable_logs, true)
  enable_metrics_collection = try(local.obs.enable_metrics, true)
  logs_retention_days      = min(730, try(local.obs.logs_retention_days, 730))
  artifacts_path           = try(local.root.helm_charts.artifacts_path, null)
}