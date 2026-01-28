resource "google_compute_router" "divyam_router_egress_nat_router" {
  name    = var.router_name
  region  = var.region
  network = var.network
}


resource "google_compute_router_nat" "nat_config" {
  name   = var.nat_config_name
  router = google_compute_router.divyam_router_egress_nat_router.name
  region = google_compute_router.divyam_router_egress_nat_router.region

  # Tells NAT to automatically allocate external IP addresses.
  nat_ip_allocate_option = "AUTO_ONLY"

  # Applies NAT to all subnets (and all IP ranges) attached to the router’s network.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = { for idx, val in var.nat_subnetworks : idx => val }
    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.cidrs
    }
  }
}

