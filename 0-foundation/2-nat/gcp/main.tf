# GCP Cloud NAT — Cloud Router + NAT config for egress (source: gcp/nat).

resource "google_compute_router" "egress_nat_router" {
  count = var.enabled ? 1 : 0

  name    = var.router_name
  region  = var.region
  network = var.network
  project = var.project_id

  lifecycle {
    # Avoid replacing imported router when dependency outputs differ (e.g. run-all plan) or network is same VPC by different ref
    ignore_changes = [network]
  }
}

resource "google_compute_router_nat" "nat_config" {
  count = var.enabled ? 1 : 0

  name   = var.nat_config_name
  router = google_compute_router.egress_nat_router[0].name
  region = google_compute_router.egress_nat_router[0].region
  project = var.project_id

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = { for idx, val in var.nat_subnetworks : idx => val if val.name != null && val.name != "" }
    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.cidrs
    }
  }

  lifecycle {
    # Preserve imported NAT subnetwork config when dependency outputs missing or format differs (e.g. ALL_IP_RANGES vs specific CIDRs)
    ignore_changes = [subnetwork]
  }
}
