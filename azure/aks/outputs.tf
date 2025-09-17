output "aks_cluster_names" {
  description = "Names of all deployed AKS clusters"
  value       = { for k, v in azurerm_kubernetes_cluster.aks_cluster : k => v.name }
}

output "aks_cluster_ids" {
  description = "IDs of all AKS clusters"
  value       = { for k, v in azurerm_kubernetes_cluster.aks_cluster : k => v.id }
}

output "aks_kube_config" {
  description = "Kubeconfig for AKS clusters"
  value       = { for k, v in azurerm_kubernetes_cluster.aks_cluster : k => v.kube_config[0] }
  sensitive   = true
}

output "aks_kube_config_raw" {
  description = "Raw kubeconfig for AKS clusters"
  value       = { for k, v in azurerm_kubernetes_cluster.aks_cluster : k => v.kube_config_raw }
  sensitive   = true
}

output "aks_node_resource_groups" {
  description = "Node resource groups created for each AKS cluster"
  value       = { for k, v in azurerm_kubernetes_cluster.aks_cluster : k => v.node_resource_group }
}

output "additional_node_pool_ids" {
  description = "IDs of GPU-enabled node pools"
  value       = { for k, v in azurerm_kubernetes_cluster_node_pool.additional_node_pools : k => v.id }
}

output "aks_oidc_issuer_urls" {
  value     = { for k, v in azurerm_kubernetes_cluster.aks_cluster : k => v.oidc_issuer_url }
  sensitive = true
}