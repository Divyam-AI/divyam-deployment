output "aks_cluster_name" {
  description = "Name of deployed AKS cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.name
}

output "aks_cluster_id" {
  description = "ID of deployed AKS cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.id
}

output "aks_kube_config" {
  description = "Kubeconfig of deployed AKS cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config[0]
  sensitive   = true
}

output "aks_kube_config_raw" {
  description = "Raw kubeconfig of deployed AKS cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config_raw
  sensitive   = true
}

output "additional_node_pool_ids" {
  description = "IDs of additional node pools"
  value       = { for k, v in azurerm_kubernetes_cluster_node_pool.additional_node_pools : k => v.id }
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.aks_cluster.oidc_issuer_url
  sensitive   = true
}

output "monitor_workspace_name" {
  description = "Name of the monitor workspace (Prometheus)"
  value       = var.enable_metrics_collection ? azurerm_monitor_workspace.prometheus["enabled"].name : null
}

output "monitor_workspace_id" {
  description = "ID of the monitor workspace"
  value       = var.enable_metrics_collection ? azurerm_monitor_workspace.prometheus["enabled"].id : null
}
