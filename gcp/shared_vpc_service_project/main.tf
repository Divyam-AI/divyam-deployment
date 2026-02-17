provider "google" {
  project = var.service_project_id
}

resource "google_compute_shared_vpc_service_project" "attach" {
  host_project    = var.host_project_id
  service_project = var.service_project_id
}