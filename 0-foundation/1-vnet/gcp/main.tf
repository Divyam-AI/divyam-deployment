# GCP VPC

locals {
  filtered_subnets_to_create = [
    for subnet in var.vnet.subnets : { subnet_name = subnet.subnet_name, subnet = subnet } if subnet.create
  ]
  subnets_to_create = { for pair in local.filtered_subnets_to_create : pair.subnet_name => pair.subnet }

  filtered_subnets_existing = [
    for subnet in var.vnet.subnets : { subnet_name = subnet.subnet_name, subnet = subnet } if !subnet.create
  ]
  subnets_existing = { for pair in local.filtered_subnets_existing : pair.subnet_name => pair.subnet }

  # Single network reference for subnet resources (created or existing VPC).
  network_id = var.vnet.create ? google_compute_network.vpc[0].id : data.google_compute_network.vpc[0].id
}

# Create VPC when create = true.
resource "google_compute_network" "vpc" {
  count = var.vnet.create ? 1 : 0

  name                    = var.vnet.name
  project                 = var.vnet.scope_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  description = "VPC managed by Terraform."

  lifecycle {
    prevent_destroy = true
  }
}

# Look up existing VPC when create = false.
data "google_compute_network" "vpc" {
  count = var.vnet.create ? 0 : 1

  name    = var.vnet.name
  project = var.vnet.scope_name
}

# Create subnets.
resource "google_compute_subnetwork" "subnets" {
  for_each = local.subnets_to_create

  name          = each.key
  project       = var.vnet.scope_name
  region        = var.vnet.region
  network       = local.network_id
  ip_cidr_range = each.value.subnet_ip

  lifecycle {
    prevent_destroy = true
  }
}

# Look up existing subnets.
data "google_compute_subnetwork" "existing_subnets" {
  for_each = local.subnets_existing

  name    = each.key
  region  = var.vnet.region
  project = var.vnet.scope_name
}
