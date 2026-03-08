############################################
# Configure Google Provider
############################################

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

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

  _sep = "::"

  role_binding_keys = toset([
    for rb in local.role_bindings_flat :
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

  account_id   = replace(each.key, "-", "_")
  display_name = "GKE Service Account - ${each.key}"

  labels = local.rendered_tags
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
