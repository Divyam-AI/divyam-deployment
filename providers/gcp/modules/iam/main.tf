data "google_compute_default_service_account" "default" {
  project = var.project_id
}

module "artifact_registry_iam" {
  count = var.artifact_registry.create_iam ? 1 : 0
  source  = "terraform-google-modules/iam/google//modules/artifact_registry_iam"
  version = "~> 8.0"   # Adjust version as needed

  project  = var.artifact_registry.artifact_registry_project          
  location = var.artifact_registry.artifact_registry_project_region
  repositories = var.artifact_registry.artifact_repositories

  bindings = {
    "roles/artifactregistry.reader" = [
        "serviceAccount:${var.artifact_registry.service_account != "" ? var.artifact_registry.service_account : data.google_compute_default_service_account.default.email}"
      ]
    }
}

resource "google_storage_bucket_iam_binding" "bucket_read_access" {
  count = var.ci_cd.bucket_access ? 1 : 0
  bucket = "divyam-ci-cd"  # the bucket name

  role    = "roles/storage.objectAdmin"
  members = [
        "serviceAccount:${var.ci_cd.service_account != "" ? var.ci_cd.service_account : data.google_compute_default_service_account.default.email}"
  ]
}

resource "google_storage_bucket_iam_binding" "bucket_admin_access" {
  count = var.ci_cd.bucket_access ? 1 : 0
  bucket = "divyam-ci-cd"  # the bucket name

  role    = "roles/storage.admin"
  members = [
    "serviceAccount:${var.ci_cd.service_account != "" ? var.ci_cd.service_account : data.google_compute_default_service_account.default.email}"
  ]
}

resource "google_project_iam_member" "ci_cd_iam_compute" {
  count = var.ci_cd.create_iam ? 1 : 0
  project = var.project_id
  role    = "roles/compute.serviceAgent"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "ci_cd_iam_container" {
  count = var.ci_cd.create_iam ? 1 : 0
  project = var.project_id
  role    = "roles/container.serviceAgent"
  member  = "serviceAccount:${var.ci_cd.service_account != "" ? var.ci_cd.service_account :  data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "prometheus_metric_writer_iam" {
  count = var.prometheus_metric_writer.create_iam ? 1 : 0
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${var.prometheus_metric_writer.service_account != "" ? var.prometheus_metric_writer.service_account :  data.google_compute_default_service_account.default.email}"
}

# Add IAM policy binding to allow google service account to impersonate the kubernetes service account
resource "google_project_iam_member" "default_node_service_account_iam" {
  count = var.default_node_service_account.create_iam ? 1 : 0
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${var.default_node_service_account.service_account != "" ? var.default_node_service_account.service_account :  data.google_compute_default_service_account.default.email}"
}

## ----- Router Controller IAM Bindings -----
# Create the service account for the router controller
resource "google_service_account" "router_controller" {
  count = var.router_controller.create_sa ? 1 : 0
  account_id   = "${var.router_controller.service_account}"
  display_name = "GKE Service Router Controller"
}

# Add IAM policy binding to allow google service account to impersonate the kubernetes service account
resource "google_service_account_iam_member" "router_controller_iam" {
  count = var.router_controller.create_sa ? 1 : 0
  service_account_id = google_service_account.router_controller[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.router_controller.namespace}/${var.router_controller.service_account}]"
}

resource "google_project_iam_member" "router_controller_secret_manager_iam" {
  count = var.router_controller.create_sa ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.router_controller.service_account}@${var.project_id}.iam.gserviceaccount.com"
}


## ----- Secrets Manager IAM Bindings -----
# Create the Google Service Account for accessing Secret Manager
resource "google_service_account" "secrets_accessor" {
  count = var.secrets_accessor.create_sa ? 1 : 0
  account_id   = "${var.secrets_accessor.service_account}"
  display_name = "Service Account for accessing Secret Manager"
}

# Give the Google Service Account the permission to access the secret manager
resource "google_project_iam_member" "secret_accessor_iam_role" {
  count = var.secrets_accessor.create_sa ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.secrets_accessor.service_account}@${var.project_id}.iam.gserviceaccount.com"
}

# Add IAM policy binding to allow K8s specific K8s Service Accounts to impersonate the Google Service Account
resource "google_service_account_iam_member" "secret_accessor_gsa_ksa_map" {
    for_each = {
    for pair in var.ksa_bindings_for_secret_access :
    "${pair.namespace}/${pair.name}" => pair
  }

  service_account_id = google_service_account.secrets_accessor[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.name}]"
}

## ----- Kafka Connect IAM Bindings -----
# Create the service account for KafkaConnect
resource "google_service_account" "kafka_connect" {
  count = var.kafka_connect.create_sa ? 1 : 0
  account_id   = "${var.kafka_connect.service_account}"
  display_name = "GKE Service Kafka Connect"
}

# Add IAM policy binding to allow google service account to impersonate the kubernetes service account
resource "google_service_account_iam_member" "kafka_connect_iam" {
  count = var.kafka_connect.create_sa ? 1 : 0
  service_account_id = google_service_account.kafka_connect[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kafka_connect.namespace}/${var.kafka_connect.service_account}]"
}

resource "google_project_iam_member" "kafka_connect_storage_admin_iam" {
  count = var.kafka_connect.create_sa ? 1 : 0
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${var.kafka_connect.service_account}@${var.project_id}.iam.gserviceaccount.com"
}

## ----- Billing IAM Bindings -----
# Create the service account for billing
resource "google_service_account" "billing" {
  count = var.billing.create_sa ? 1 : 0
  account_id   = "${var.billing.service_account}"
  display_name = "GKE Service billing"
}

# Add IAM policy binding to allow billing google service account to impersonate the billing kubernetes service account
resource "google_service_account_iam_member" "billing_iam" {
  count = var.billing.create_sa ? 1 : 0
  service_account_id = google_service_account.billing[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.billing.namespace}/${var.billing.service_account}]"
}

# Give access for billing service account to bigQuery
resource "google_project_iam_member" "bigQuery_jobUser_iam" {
  count = var.billing.create_sa ? 1 : 0
  project = var.billing.billing_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${var.billing.service_account}@${var.project_id}.iam.gserviceaccount.com"
}

# Give access for billing service account to access secrets
resource "google_project_iam_member" "billing_secrets_manager_iam" {
  count = var.billing.create_sa ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.billing.service_account}@${var.project_id}.iam.gserviceaccount.com"
}

# Grant BigQuery Data Viewer role at dataset level to billing service account
resource "google_bigquery_dataset_iam_member" "billing_dataset_viewer" {
  project    = var.billing.billing_project_id
  dataset_id = var.billing.billing_dataset_id
  role       = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${var.billing.service_account}@${var.project_id}.iam.gserviceaccount.com"
}


## ----- Eval Job IAM Bindings -----
# Create the service account for eval job
resource "google_service_account" "eval_sa" {
  count        = var.eval.create_sa ? 1 : 0
  account_id   = "${var.eval.service_account}"
  display_name = "Eval Job Service Account"
}

# Add IAM policy binding to allow eval job KSA to impersonate the eval GSA
resource "google_service_account_iam_member" "eval_ksa_impersonation" {
  count              = var.eval.create_sa ? 1 : 0
  service_account_id = google_service_account.eval_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.eval.namespace}/${var.eval.service_account}]"
}

# Give access for eval service account to access secrets
resource "google_project_iam_member" "eval_secrets_manager_iam" {
  count   = var.eval.create_sa ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.eval.service_account}@${var.project_id}.iam.gserviceaccount.com"
}