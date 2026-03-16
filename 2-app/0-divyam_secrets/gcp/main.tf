# Divyam secrets: uses common module for secrets map, creates GCP Secret Manager secrets.
# Labels use root-generated local.rendered_tags; per-resource names so each secret gets its actual name in labels.
# common module block is in generated common_module.tf (path set by Terragrunt so it works in cache).
# Re-running with new values updates existing secrets (adds a new version in Secret Manager).

# Per-resource labels: each secret gets its actual name (secret_id) in labels.
locals {
  rendered_tags_for_secrets = var.create_secrets ? {
    for name in toset(module.common.secret_names) : name => {
      for tag_k, tag_v in var.common_tags : tag_k => replace(tag_v, "/#\\{([^}]+)\\}/", (lookup(merge(local.tag_context, { resource_name = name }), try(regex("#\\{([^}]+)\\}", tag_v)[0], ""), "")))
    }
  } : {}
}

resource "google_secret_manager_secret" "secrets" {
  for_each  = var.create_secrets ? toset(module.common.secret_names) : toset([])
  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.rendered_tags_for_secrets[each.key]
}

resource "google_secret_manager_secret_version" "secrets" {
  for_each    = var.create_secrets ? toset(module.common.secret_names) : toset([])
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = module.common.secrets[each.key]
}
