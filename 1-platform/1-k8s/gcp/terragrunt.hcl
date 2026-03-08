# GKE cluster (1-platform). Config from values/defaults.hcl k8s (k8s.gke when CLOUD_PROVIDER=gcp).
# VNet names from merged config; network/subnetwork self links built here for the GKE resource.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

# Provider with project/region for this module (root's provider has no project).
generate "provider_gke" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
EOT
}

locals {
  root   = include.root.locals.merged
  k8s    = try(local.root.k8s, {})
  net    = try(local.k8s.network, {})
  pools  = try(local.k8s.node_pools, {})
  obs    = try(local.k8s.observability, {})
  vnet   = try(local.root.vnet, {})
  project = local.root.resource_scope.name
  region  = local.root.region

  # Single cluster: k8s.name; region/vnet from root. enable_autopilot from cloud-agnostic node_provisioning_mode ("Auto" = Autopilot).
  cluster_config = {
    region                    = local.region
    release_channel           = try(local.k8s.release_channel, "REGULAR")
    enable_autopilot          = try(local.k8s.node_provisioning_mode, "Manual") == "Auto"
    machine_type              = try(local.pools.default.instance_type, "e2-standard-4")
    enable_private_nodes      = try(local.net.private_cluster_enabled, true)
    enable_private_endpoint   = true
    network                   = "projects/${local.project}/global/networks/${try(local.vnet.name, "default")}"
    subnetwork                = "projects/${local.project}/regions/${local.region}/subnetworks/${try(local.vnet.subnet.name, "default")}"
    master_authorized_networks_cidr = [for c in try(local.net.api_server_authorized_ip_ranges, []) : { cidr_block = c, display_name = c }]
    cluster_ipv4_cidr        = try(local.net.pod_cidr, "10.2.0.0/16")
    services_ipv4_cidr       = try(local.net.services_cidr, "10.3.0.0/16")
    additional_pod_range_names = []
    binauthz_evaluation_mode  = "DISABLED"
    dns_scope                 = "CLUSTER_SCOPE"
    dns_domain                = ""
    enable_workload_logs      = try(local.obs.enable_logs, true)
    enable_cluster_logs       = try(local.obs.enable_logs, true)
  }
  clusters_with_links = { (local.k8s.name) = local.cluster_config }
  # Additional node pools (GCP shape): machine_type from instance_type (single value per cloud from defaults ternary) or legacy keys.
  additional_node_pools = { for name, pool in try(local.pools.additional, {}) : name => {
    machine_type = try(pool.instance_type, pool.machine_type, pool.vm_size, "e2-standard-4")
    node_count   = try(pool.count, 1)
    auto_scaling = try(pool.auto_scaling, false)
    min_count    = try(pool.min_count, null)
    max_count    = try(pool.max_count, null)
    node_taints  = try(pool.node_taints, [])
    node_labels  = try(pool.node_labels, {})
  } }
}

# Pass tagging inputs like 0-foundation/1-vnet so root generate "tagging" produces local.rendered_tags.
inputs = merge(
  {
    enabled               = local.k8s.create
    project_id            = local.project
    region                = local.region
    cluster_name          = local.k8s.create ? null : local.k8s.name
    clusters              = local.k8s.create ? local.clusters_with_links : {}
    additional_node_pools = local.additional_node_pools
    common_tags           = try(local.root.common_tags, {})
    tag_globals           = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.k8s.name
    }
  }
)
