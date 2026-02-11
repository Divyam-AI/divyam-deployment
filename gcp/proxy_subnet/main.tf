// main.tf
resource "google_compute_subnetwork" "proxy_only_subnet" {
  project       = var.project_id
  region        = var.region
  name          = var.subnet_name
  ip_cidr_range = var.ip_cidr_range
  network       = var.network_self_link
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"

}