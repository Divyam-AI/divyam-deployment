############################################
# Service Accounts (shared common module)
############################################

module "service_accounts" {
  source   = "../common"
  env_name = var.env_name
}

############################################
# Locals (from common module + gcp_iam_role_mapping.tf)
############################################

locals {

  service_accounts = module.service_accounts.service_accounts

  service_account_ids = toset(keys(local.service_accounts))

  # Per-resource labels so each service account gets its name and divyam_environment.
  tag_context_base = merge(var.tag_globals, var.tag_context)
  rendered_tags_for_sa = {
    for name in local.service_account_ids : name => {
      for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), ""))
    }
  }

  scope_ids = {
    project        = var.project_id
    storage_bucket = var.router_logs_bucket_name
  }

  sa_role_pairs = flatten([
    for sa_name, sa in local.service_accounts : [
      for role in sa.roles : {
        sa_name = sa_name
        role    = role
      }
    ]
  ])

  valid_role_pairs = [
    for pair in local.sa_role_pairs :
    pair if lookup(local.role_mapping, pair.role, null) != null
  ]

  role_bindings_flat = flatten([
    for pair in local.valid_role_pairs : [
      for rb in local.role_mapping[pair.role].role_bindings : {
        sa_name = pair.sa_name
        scope   = rb.scope
        role    = rb.role
      }
    ]
  ])

  # Exclude storage_bucket scope when bucket name is not set (defaults or optional).
  role_bindings_flat_filtered = [
    for rb in local.role_bindings_flat :
    rb if rb.scope != "storage_bucket" || var.router_logs_bucket_name != null
  ]

  _sep = "::"

  role_binding_keys = toset([
    for rb in local.role_bindings_flat_filtered :
    "${rb.sa_name}${local._sep}${rb.scope}${local._sep}${rb.role}"
  ])

  role_binding_map = {
    for key in local.role_binding_keys :
    key => {
      sa_name = split(local._sep, key)[0]
      scope   = split(local._sep, key)[1]
      role    = split(local._sep, key)[2]
    }
  }
}

############################################
# Google Service Accounts (1 per logical SA)
############################################

resource "google_service_account" "identities" {
  for_each = local.service_account_ids

  project      = var.project_id
  account_id   = each.key
  display_name = "GKE Service Account - ${each.key}"
}

############################################
# Project IAM Bindings
############################################

resource "google_project_iam_member" "project_roles" {
  for_each = {
    for k, v in local.role_binding_map :
    k => v if v.scope == "project"
  }

  project = local.scope_ids.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.identities[each.value.sa_name].email}"
}

############################################
# Storage Bucket IAM Bindings
############################################

resource "google_storage_bucket_iam_member" "bucket_roles" {
  for_each = {
    for k, v in local.role_binding_map :
    k => v if v.scope == "storage_bucket"
  }

  bucket = local.scope_ids.storage_bucket
  role   = each.value.role
  member = "serviceAccount:${google_service_account.identities[each.value.sa_name].email}"
}

############################################
# Workload Identity (KSA → GSA)
############################################

resource "google_service_account_iam_member" "workload_identity" {
  for_each = local.service_accounts

  service_account_id = google_service_account.identities[each.key].name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.key}]"
}
