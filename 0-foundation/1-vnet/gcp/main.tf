# GCP VPC — single subnet, single app_gw_subnet (source of truth: values/defaults.hcl).

locals {
  network_id = var.vnet.create ? google_compute_network.vpc[0].id : data.google_compute_network.vpc[0].id
}

resource "google_compute_network" "vpc" {
  count = var.vnet.create ? 1 : 0

  name                    = var.vnet.name
  project                 = var.vnet.scope_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "VPC managed by Terraform."

  lifecycle {
    prevent_destroy = true
    # default VPC uses REGIONAL; new VPCs often use GLOBAL; avoid changing existing networks
    ignore_changes = [auto_create_subnetworks, description, routing_mode]
  }
}

data "google_compute_network" "vpc" {
  count = var.vnet.create ? 0 : 1

  name    = var.vnet.name
  project = var.vnet.scope_name
}

resource "google_compute_subnetwork" "subnet" {
  count = var.vnet.subnet.create ? 1 : 0

  name          = var.vnet.subnet.name
  project       = var.vnet.scope_name
  region        = var.vnet.region
  network       = local.network_id
  ip_cidr_range = var.vnet.subnet.subnet_ip

  lifecycle {
    prevent_destroy = true
    # GKE adds secondary ranges for pods/services; do not remove them when not in config
    ignore_changes = [secondary_ip_range]
  }
}

data "google_compute_subnetwork" "subnet" {
  count = var.vnet.subnet.create ? 0 : 1

  name    = var.vnet.subnet.name
  region  = var.vnet.region
  project = var.vnet.scope_name
}

resource "google_compute_subnetwork" "app_gw_subnet" {
  count = var.vnet.app_gw_subnet.create ? 1 : 0

  name          = var.vnet.app_gw_subnet.name
  project       = var.vnet.scope_name
  region        = var.vnet.region
  network       = local.network_id
  ip_cidr_range = var.vnet.app_gw_subnet.subnet_ip
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"

  lifecycle {
    prevent_destroy = true
    # Preserve secondary ranges if added (e.g. by GKE or other services)
    ignore_changes = [secondary_ip_range]
  }
}

data "google_compute_subnetwork" "app_gw_subnet" {
  count = var.vnet.app_gw_subnet.create ? 0 : 1

  name    = var.vnet.app_gw_subnet.name
  region  = var.vnet.region
  project = var.vnet.scope_name
}

# --- GCP Shared VPC (host + service project attachments) ---
# Enable the project that owns the VPC as a Shared VPC host (only when creating the VPC).
resource "google_compute_shared_vpc_host_project" "host" {
  count = (var.vnet.create) && try(var.vnet.shared_vpc_host, false) ? 1 : 0

  project = var.vnet.scope_name
}

# Attach service projects to this Shared VPC.
resource "google_compute_shared_vpc_service_project" "service_projects" {
  for_each = (var.vnet.create) && try(var.vnet.shared_vpc_host, false) ? toset(try(var.vnet.service_project_ids, [])) : toset([])

  host_project    = var.vnet.scope_name
  service_project = each.key
}
