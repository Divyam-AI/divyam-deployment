# GCP native observability: project log bucket retention + GKE logging/GMP on the cluster.
# Cluster lifecycle remains in 1-k8s/gcp; this module updates observability settings only.

locals {
  tag_context_base = merge(var.tag_globals, var.tag_context)

  logging_components = (
    var.enable_workload_logs && var.enable_cluster_logs ? [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
      "WORKLOADS",
    ] :
    var.enable_cluster_logs ? [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
    ] :
    var.enable_workload_logs ? [
      "WORKLOADS",
    ] : []
  )

  manage_cluster_observability = var.enabled && var.cluster_name != null && var.cluster_name != "" && (
    var.enable_workload_logs || var.enable_cluster_logs || var.enable_managed_prometheus
  )

  observability_clusters = local.manage_cluster_observability ? { primary = var.cluster_name } : {}
}

resource "google_logging_project_bucket_config" "default_bucket" {
  count          = var.enabled && var.manage_project_log_bucket ? 1 : 0
  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = min(3650, max(1, var.logs_retention_days))
}

data "google_container_cluster" "primary" {
  for_each = local.observability_clusters

  name     = each.value
  location = var.region
  project  = var.project_id
}

import {
  for_each = local.observability_clusters
  to       = google_container_cluster.observability[each.key]
  id       = "projects/${var.project_id}/locations/${var.region}/clusters/${each.value}"
}

resource "google_container_cluster" "observability" {
  for_each = local.observability_clusters

  name     = each.value
  location = var.region
  project  = var.project_id

  dynamic "logging_config" {
    for_each = (var.enable_workload_logs || var.enable_cluster_logs) ? [1] : []
    content {
      enable_components = local.logging_components
    }
  }

  dynamic "monitoring_config" {
    for_each = var.enable_managed_prometheus ? [1] : []
    content {
      enable_components = ["SYSTEM_COMPONENTS"]
      managed_prometheus {
        enabled = true
      }
    }
  }

  lifecycle {
    ignore_changes = [
      addons_config,
      authenticator_groups_config,
      binary_authorization,
      cluster_autoscaling,
      cluster_ipv4_cidr,
      cost_management_config,
      database_encryption,
      default_max_pods_per_node,
      deletion_protection,
      dns_config,
      enable_autopilot,
      enable_kubernetes_alpha,
      enable_legacy_abac,
      enable_shielded_nodes,
      enable_tpu,
      gateway_api_config,
      identity_service_config,
      initial_node_count,
      ip_allocation_policy,
      logging_service,
      maintenance_policy,
      master_authorized_networks_config,
      mesh_certificates,
      min_master_version,
      monitoring_service,
      network,
      network_policy,
      node_config,
      node_pool,
      notification_config,
      private_cluster_config,
      release_channel,
      remove_default_node_pool,
      resource_labels,
      security_posture_config,
      service_external_ips_config,
      subnetwork,
      vertical_pod_autoscaling,
      workload_identity_config,
    ]
  }
}
