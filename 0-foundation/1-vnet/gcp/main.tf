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

  lifecycle {
    prevent_destroy = true
  }
}

data "google_compute_subnetwork" "app_gw_subnet" {
  count = var.vnet.app_gw_subnet.create ? 0 : 1

  name    = var.vnet.app_gw_subnet.name
  region  = var.vnet.region
  project = var.vnet.scope_name
}
