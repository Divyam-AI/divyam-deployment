# Divyam secrets: uses common module for secrets map, creates GCP Secret Manager secrets.
# Labels use root-generated local.rendered_tags.
# common module block is in generated common_module.tf (path set by Terragrunt so it works in cache).
# Re-running with new values updates existing secrets (adds a new version in Secret Manager).

resource "google_secret_manager_secret" "secrets" {
  for_each  = var.create_secrets ? toset(module.common.secret_names) : toset([])
  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.rendered_tags
}

resource "google_secret_manager_secret_version" "secrets" {
  for_each    = var.create_secrets ? toset(module.common.secret_names) : toset([])
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = module.common.secrets[each.key]
}
