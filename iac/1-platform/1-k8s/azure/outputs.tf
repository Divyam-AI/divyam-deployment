output "aks_cluster_name" {
  description = "Name of deployed or existing AKS cluster"
  value       = local.aks_cluster.name
}

output "aks_cluster_id" {
  description = "ID of deployed or existing AKS cluster"
  value       = local.aks_cluster.id
}

output "aks_kube_config" {
  description = "Kubeconfig of AKS cluster (created or looked up)"
  value       = local.aks_cluster.kube_config[0]
  sensitive   = true
}

output "aks_kube_config_raw" {
  description = "Raw kubeconfig of AKS cluster"
  value       = local.aks_cluster.kube_config_raw
  sensitive   = true
}

output "additional_node_pool_ids" {
  description = "IDs of additional node pools (empty when create = false)"
  value       = var.create ? { for k, v in azurerm_kubernetes_cluster_node_pool.additional_node_pools : k => v.id } : {}
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = local.aks_cluster.oidc_issuer_url
  sensitive   = true
}

output "dns_prefix_configured" {
  description = "DNS prefix used for the AKS API server hostname (e.g. {prefix}.{region}.azmk8s.io). Defaults to cluster name in terragrunt."
  value       = local.aks_cluster.dns_prefix
}

output "release_channel_configured" {
  description = "AKS automatic upgrade channel (patch|rapid|stable|node-image). From k8s.release_channel when cloud_provider=azure."
  value       = var.cluster.automatic_channel_upgrade
}

output "aks_api_fqdn" {
  description = "FQDN of the AKS API server (derived from dns_prefix)"
  value       = local.aks_cluster.fqdn
}

output "monitor_workspace_name" {
  description = "Name of the monitor workspace (Prometheus); null when create = false or metrics disabled"
  value       = var.create && var.enable_metrics_collection ? azurerm_monitor_workspace.prometheus["enabled"].name : null
}

output "monitor_workspace_id" {
  description = "ID of the monitor workspace; null when create = false or metrics disabled"
  value       = var.create && var.enable_metrics_collection ? azurerm_monitor_workspace.prometheus["enabled"].id : null
}

output aks_principal_id {
  description = "Principal ID of the AKS cluster"
  value       = local.aks_cluster.identity[0].principal_id
}