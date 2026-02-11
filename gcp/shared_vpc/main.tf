provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "shared_vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  description             = "Shared VPC in host project"
}

resource "google_compute_subnetwork" "subnets" {
  for_each       = { for s in var.subnets : s.subnet_name => s }
  name           = each.value.subnet_name
  ip_cidr_range  = each.value.subnet_ip
  region         = each.value.region
  network        = google_compute_network.shared_vpc.id

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
      reserved_internal_range = try(secondary_ip_range.value.reserved_internal_range, null)
    }
  }
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = var.project_id
}