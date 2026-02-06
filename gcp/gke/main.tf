terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Create one GKE (Autopilot) cluster per entry in var.clusters.
resource "google_container_cluster" "gke_cluster" {
  for_each = var.clusters
  name     = each.key
  location = var.region
  
  deletion_protection = false # make it false to destroy the cluster

  initial_node_count = 1
  enable_autopilot   = true
  # Use the release channel (e.g. REGULAR, RAPID, STABLE)
  release_channel {
    channel = each.value.release_channel
  }

  network    = each.value.network
  subnetwork = each.value.subnetwork

  dns_config {
    additive_vpc_scope_dns_domain = each.value.dns_domain
    cluster_dns = "CLOUD_DNS"
    cluster_dns_scope = each.value.dns_scope
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = each.value.cluster_ipv4_cidr    
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

  /*
    OPTIONAL: If there are attributes that you want to “lock” for an existing cluster so that
    later variable changes do not cause Terraform to update (or recreate) that cluster, you can
    use a lifecycle block with ignore_changes. For example, if you don’t want changes to the
    release_channel block to force an update on a particular cluster:
  */
  lifecycle {
    # For example, to ignore changes in the release channel:
    ignore_changes = [
      release_channel,dns_config[0].additive_vpc_scope_dns_domain
      // You can list other arguments to ignore if needed.
    ]
  }
}

