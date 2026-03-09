# GCP Cloud NAT — Cloud Router + NAT config for egress (source: gcp/nat).

locals {
  tag_context_base     = merge(var.tag_globals, var.tag_context)
  rendered_tags_router = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = var.router_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

resource "google_compute_router" "egress_nat_router" {
  count = var.enabled ? 1 : 0

  name    = var.router_name
  region  = var.region
  network = var.network
  project = var.project_id

  labels = local.rendered_tags_router
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
    for_each = { for idx, val in var.nat_subnetworks : idx => val }
    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.cidrs
    }
  }
}
