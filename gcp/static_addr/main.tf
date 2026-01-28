resource "google_compute_global_address" "static_address" {
  name        = var.address_name
  description = "Static address for ingress load balancer"
  # Optionally specify the project here if not using the provider's default project.
  project = var.project_id
}

resource "google_compute_global_address" "dashboard_static_address" {
  name        = var.dashboard_address_name
  description = "Static address for usage dashboard ingress load balancer"
  # Optionally specify the project here if not using the provider's default project.
  project = var.project_id
}

resource "google_compute_global_address" "test_static_address" {
  name        = var.test_address_name
  description = "Static address for Testing ingress load balancer"
  # Optionally specify the project here if not using the provider's default project.
  project = var.project_id
}