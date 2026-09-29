# GKE (Autopilot) cluster(s). Config from values/defaults.hcl k8s.gke.
# When enabled = false, fetch existing cluster by cluster_name and output details.

# When enabled = false, look up existing cluster by name.
data "google_container_cluster" "existing" {
  count    = var.enabled ? 0 : 1
  name     = var.cluster_name
  location = coalesce(var.location, var.region)
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
  location = coalesce(var.location, var.region)

  deletion_protection = false

  initial_node_count = 1
  # Autopilot manages its own nodes, so there is no default pool to remove. Sent as null rather
  # than false for the same reason as enable_autopilot below: the conflict check fires on the
  # attribute being present, whatever it is set to.
  remove_default_node_pool = each.value.enable_autopilot ? null : each.value.remove_default_node_pool
  # null rather than false: the provider rejects enable_autopilot alongside cluster_autoscaling
  # whenever the attribute is present at all, regardless of its value.
  enable_autopilot = each.value.enable_autopilot ? true : null

  resource_labels = local.rendered_tags_for_cluster[each.key]

  # Describes the default pool GKE creates at cluster creation. Omitted when that pool is being
  # removed: the block would otherwise keep drifting against a pool that no longer exists, and
  # oauth_scopes is replace-only, so the drift reads as "recreate the cluster".
  dynamic "node_config" {
    for_each = each.value.enable_autopilot || each.value.remove_default_node_pool ? [] : [1]
    content {
      machine_type = each.value.machine_type
      disk_size_gb = 100
      spot         = each.value.use_spot
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      labels = local.rendered_tags_for_cluster[each.key]

      # Serves the KSA token that workload_identity_config above federates. Without it a pod falls
      # back to the node's service account, which is the wrong identity, not a failure to authenticate.
      workload_metadata_config {
        mode = "GKE_METADATA"
      }
    }
  }

  # Node auto-provisioning. Autopilot manages this itself, so it is set only for standard clusters.
  # Pods drive it directly: a Pod selecting cloud.google.com/gke-spot (plus the matching toleration)
  # gets a spot pool, one selecting cloud.google.com/gke-accelerator gets a GPU pool. No default
  # ComputeClass, so nothing lands on spot or on-demand without having asked for it.
  dynamic "cluster_autoscaling" {
    for_each = !each.value.enable_autopilot && each.value.node_auto_provisioning != null ? [1] : []
    content {
      enabled                       = true
      default_compute_class_enabled = false
      # Pack pods tighter and scale nodes down sooner; the point of auto-provisioning here is cost.
      autoscaling_profile = "OPTIMIZE_UTILIZATION"

      resource_limits {
        resource_type = "cpu"
        maximum       = each.value.node_auto_provisioning.max_cpu
      }
      resource_limits {
        resource_type = "memory"
        maximum       = each.value.node_auto_provisioning.max_memory_gb
      }
      dynamic "resource_limits" {
        for_each = each.value.node_auto_provisioning.max_accelerators
        content {
          resource_type = resource_limits.key
          maximum       = resource_limits.value
        }
      }
    }
  }

  cost_management_config {
    enabled = each.value.enable_cost_allocation
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

  # Omitted when no ranges are given. An empty block is not "unrestricted" — it means authorized
  # networks are on with nothing permitted, which locks every caller out of the API server.
  dynamic "master_authorized_networks_config" {
    for_each = length(each.value.master_authorized_networks_cidr) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = each.value.master_authorized_networks_cidr
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  binary_authorization {
    evaluation_mode = each.value.binauthz_evaluation_mode
  }

  # Workload Identity Federation. Not optional: 2-app/1-iam_bindings grants
  # roles/iam.workloadIdentityUser to serviceAccount:<project>.svc.id.goog[<ns>/<ksa>], and that
  # principal only exists once the cluster declares the pool. Without it every token exchange 404s,
  # so External Secrets cannot reach Secret Manager and no chart that reads a secret can start.
  # The pool name is fixed by GCP — derived, never configurable, so it cannot drift from the bindings.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  lifecycle {
    ignore_changes = [
      release_channel,
      dns_config[0].additive_vpc_scope_dns_domain,
      # Managed by 1-platform/2-monitoring/native/gcp after cluster creation.
      logging_config,
      monitoring_config,
    ]
  }
}

# Additional node pools (e.g. GPU). Only for standard (non-Autopilot) clusters.
resource "google_container_node_pool" "additional" {
  for_each   = local.additional_pool_key
  cluster    = google_container_cluster.gke_cluster[each.value.cluster_key].name
  location   = coalesce(var.location, var.region)
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
    spot         = try(var.additional_node_pools[each.value.pool_key].use_spot, false)
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = merge(
      var.additional_node_pools[each.value.pool_key].node_labels,
      local.rendered_tags_for_pool[each.key]
    )

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    dynamic "taint" {
      for_each = local.taints_parsed[each.key]
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  # node_count is resized out of band (a fixed pool is scaled to 0 and back to
  # park/wake the cluster), so a routine apply must not read that as drift and
  # revert it. An autoscaling pool has node_count = null, so ignoring it is a no-op.
  lifecycle {
    ignore_changes = [node_count]
  }
}
