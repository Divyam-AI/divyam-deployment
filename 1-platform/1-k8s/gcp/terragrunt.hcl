# GKE cluster (1-platform). Config from values/defaults.hcl k8s. VNet/subnet by name; service/pod CIDRs from vnet config (GCP API has no single VPC address_space).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "app_gw" {
  config_path = "../../0-app_gw/gcp"
  mock_outputs = {
    load_balancer_ip = ""
    cloud_armor_policy_id = null
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
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

  # K8s pod/services CIDRs from vnet config (GCP VPC has no address_space in API; use config so they don't overlap node/app_gw subnets).
  vnet_address_space = try(local.vnet.address_space[0], "10.0.0.0/16")
  k8s_pod_cidr       = cidrsubnet(local.vnet_address_space, 4, 2)
  k8s_services_cidr = cidrsubnet(local.vnet_address_space, 4, 3)

  # Single cluster: k8s.name; region/vnet from root. enable_autopilot from cloud-agnostic node_provisioning_mode ("Auto" = Autopilot).
  cluster_config = {
    region                    = local.region
    release_channel           = try(local.k8s.release_channel, "REGULAR")
    enable_autopilot          = try(local.k8s.node_provisioning_mode, "Manual") == "Auto"
    machine_type              = try(local.pools.default.instance_type, "e2-standard-4")
    enable_private_nodes      = true
    enable_private_endpoint   = true
    network                   = "projects/${local.project}/global/networks/${try(local.vnet.name, "default")}"
    subnetwork                = "projects/${local.project}/regions/${local.region}/subnetworks/${try(local.vnet.subnet.name, "default")}"
    master_authorized_networks_cidr = [for c in try(local.k8s.api_server_authorized_ip_ranges, []) : { cidr_block = c, display_name = c }]
    cluster_ipv4_cidr        = local.k8s_pod_cidr
    services_ipv4_cidr       = local.k8s_services_cidr
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
    use_spot     = try(pool.spot_instance, false)
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
    logs_retention_days   = min(3650, max(1, try(local.obs.logs_retention_days, 3650)))
    common_tags           = try(local.root.common_tags, {})
    tag_globals           = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.k8s.name
    }
  }
)
