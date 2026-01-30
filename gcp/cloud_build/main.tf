data "google_compute_default_service_account" "default" {
  project = var.project_id
}

resource "google_cloudbuild_worker_pool" "private_pool" {
  name     = "divyam-private-pool"
  location = var.region

  network_config {
    peered_network = var.shared_vpc_name
  }

  worker_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
  }

  project = var.project_id
}

# Optional: IAM Binding for Cloud Build SA to use the worker pool
resource "google_project_iam_member" "allow_cloudbuild_use_pool" {
  project = var.project_id
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${var.cloud_build.service_account != "" ? var.cloud_build.service_account : data.google_compute_default_service_account.default.email}"
}