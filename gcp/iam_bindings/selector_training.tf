
## ----- Selector Training Job IAM Bindings -----
# Create the service account for selector training job
resource "google_service_account" "selector_training_sa" {
  count        = var.selector_training.create_sa ? 1 : 0
  account_id   = "${var.selector_training.service_account}"
  display_name = "Selector Training Service Account"
}

# Allow selector training KSA to impersonate the GSA via workload identity
resource "google_service_account_iam_member" "selector_training_ksa_impersonation" {
  count              = var.selector_training.create_sa ? 1 : 0
  service_account_id = google_service_account.selector_training_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.selector_training.namespace}/${var.selector_training.service_account}]"
}

# Give selector training GSA access to Secret Manager
resource "google_project_iam_member" "selector_training_secret_access" {
  count   = var.selector_training.create_sa ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.selector_training.service_account}@${var.project_id}.iam.gserviceaccount.com"
}

# Grant GCS read/write access to a specific bucket
resource "google_storage_bucket_iam_member" "selector_training_gcs_rw_access" {
  count  = var.selector_training.create_sa ? 1 : 0
  bucket = var.selector_training.bucket_name
  role   = "roles/storage.objectAdmin" # allows read/write/delete on objects
  member = "serviceAccount:${var.selector_training.service_account}@${var.project_id}.iam.gserviceaccount.com"
}
