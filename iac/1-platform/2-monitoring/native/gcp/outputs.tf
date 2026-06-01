output "project_id" {
  value = var.project_id
}

output "cluster_name" {
  value = var.cluster_name
}

output "managed_prometheus_enabled" {
  value = var.enabled && var.enable_managed_prometheus
}
