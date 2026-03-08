# GKE (Autopilot) cluster(s). Config from values/defaults.hcl k8s.gke.
# When enabled = false, fetch existing cluster by cluster_name and output details.

# When enabled = false, look up existing cluster by name.
data "google_container_cluster" "existing" {
  count    = var.enabled ? 0 : 1
  name     = var.cluster_name
  location = var.region
  project  = var.project_id
}

locals {
  gke_clusters = var.enabled ? google_container_cluster.gke_cluster : { (var.cluster_name) = data.google_container_cluster.existing[0] }

  # Pairs (cluster_key, pool_key) for clusters that are not Autopilot.
  additional_pool_pairs = var.enabled ? flatten([
    for ck in keys(var.clusters) : [
      for pk in keys(var.additional_node_pools) :
      { cluster_key = ck, pool_key = pk }
      if !var.clusters[ck].enable_autopilot
    ]
  ]) : []
  additional_pool_key = { for p in local.additional_pool_pairs : "${p.cluster_key}-${p.pool_key}" => p }

  # Resource names = map keys (cluster: each.key, pool: each.value.pool_key). Same names used for resource creation and for tag resource_name.
  # Per-resource tags so #{resource_name} uses the actual resource name (same #{key} replacement as root generate "tagging").
  tag_context_base         = merge(var.tag_globals, var.tag_context)
  rendered_tags_for_cluster = { for ck in keys(var.clusters) : ck => { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = ck }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) } }
  rendered_tags_for_pool   = { for comp_key, p in local.additional_pool_key : comp_key => { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = p.pool_key }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) } }

  # Convert "key=value:NoSchedule" to { key, value, effect } for GKE taint.
  taints_parsed = {
    for k, p in local.additional_pool_key : k => [
      for t in try(var.additional_node_pools[p.pool_key].node_taints, []) :
      {
        key    = split("=", split(":", t)[0])[0]
        value  = split("=", split(":", t)[0])[1]
        effect = length(split(":", t)) > 1 ? replace(replace(split(":", t)[1], "NoSchedule", "NO_SCHEDULE"), "PreferNoSchedule", "PREFER_NO_SCHEDULE") : "NO_SCHEDULE"
      }
    ]
  }
}

# Create one GKE cluster per entry in var.clusters (only when enabled = true). Autopilot or standard based on enable_autopilot.
resource "google_container_cluster" "gke_cluster" {
  for_each = var.enabled ? var.clusters : {}
  name     = each.key
  location = var.region

  deletion_protection = false

  initial_node_count = each.value.enable_autopilot ? 1 : 1
  enable_autopilot   = each.value.enable_autopilot

  resource_labels = local.rendered_tags_for_cluster[each.key]

  dynamic "node_config" {
    for_each = each.value.enable_autopilot ? [] : [1]
    content {
      machine_type = each.value.machine_type
      disk_size_gb = 100
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      labels = local.rendered_tags_for_cluster[each.key]
    }
  }

  release_channel {
    channel = each.value.release_channel
  }

  network    = each.value.network
  subnetwork = each.value.subnetwork

  dns_config {
    additive_vpc_scope_dns_domain = each.value.dns_domain
    cluster_dns                   = "CLOUD_DNS"
    cluster_dns_scope             = each.value.dns_scope
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block = each.value.cluster_ipv4_cidr
    dynamic "additional_pod_ranges_config" {
      for_each = length(each.value.additional_pod_range_names) != 0 ? [1] : []
      content {
        pod_range_names = each.value.additional_pod_range_names
      }
    }
    services_ipv4_cidr_block = each.value.services_ipv4_cidr
  }

  private_cluster_config {
    enable_private_nodes    = each.value.enable_private_nodes
    enable_private_endpoint = each.value.enable_private_endpoint
    master_ipv4_cidr_block  = null
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = each.value.master_authorized_networks_cidr
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  dynamic "logging_config" {
    for_each = (each.value.enable_workload_logs != null || each.value.enable_cluster_logs != null) ? [1] : []
    content {
      enable_components = (
        each.value.enable_workload_logs && each.value.enable_cluster_logs ? [
          "SYSTEM_COMPONENTS",
          "APISERVER",
          "CONTROLLER_MANAGER",
          "SCHEDULER",
          "WORKLOADS"
        ] :
        each.value.enable_cluster_logs ? [
          "SYSTEM_COMPONENTS",
          "APISERVER",
          "CONTROLLER_MANAGER",
          "SCHEDULER"
        ] :
        each.value.enable_workload_logs ? [
          "WORKLOADS"
        ] : []
      )
    }
  }

  binary_authorization {
    evaluation_mode = each.value.binauthz_evaluation_mode
  }

  lifecycle {
    ignore_changes = [
      release_channel,
      dns_config[0].additive_vpc_scope_dns_domain
    ]
  }
}

# Additional node pools (e.g. GPU). Only for standard (non-Autopilot) clusters.
resource "google_container_node_pool" "additional" {
  for_each   = local.additional_pool_key
  cluster    = google_container_cluster.gke_cluster[each.value.cluster_key].name
  location   = var.region
  name       = each.value.pool_key
  node_count = var.additional_node_pools[each.value.pool_key].auto_scaling ? null : var.additional_node_pools[each.value.pool_key].node_count

  dynamic "autoscaling" {
    for_each = var.additional_node_pools[each.value.pool_key].auto_scaling ? [1] : []
    content {
      min_node_count = var.additional_node_pools[each.value.pool_key].min_count
      max_node_count = var.additional_node_pools[each.value.pool_key].max_count
    }
  }

  node_config {
    machine_type = var.additional_node_pools[each.value.pool_key].machine_type
    disk_size_gb = 100
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = merge(
      var.additional_node_pools[each.value.pool_key].node_labels,
      local.rendered_tags_for_pool[each.key]
    )
    dynamic "taint" {
      for_each = local.taints_parsed[each.key]
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }
}
