# Pre-prod import: use VALUES_FILE=divyam-pre-prod-defaults.hcl so deployment_prefix/names match.
# Run from repo root. Optional: set TG_USE_LOCAL_BACKEND=0 for remote state.

# 0-foundation/0-resource_scope (GCP project)
./sample_deploy.sh import 0-foundation/0-resource_scope gcp 'google_project.project[0]' pre-production-project divyam-pre-prod-defaults.hcl

# 0-foundation/1-apis (import all default APIs for project)
./sample_deploy.sh import 0-foundation/1-apis gcp google_project_service.enabled_apis pre-production-project divyam-pre-prod-defaults.hcl

# 0-foundation/1-vnet (VPC and subnets)
./sample_deploy.sh import 0-foundation/1-vnet gcp 'google_compute_network.vpc[0]' projects/pre-production-project/global/networks/default divyam-pre-prod-defaults.hcl
./sample_deploy.sh import 0-foundation/1-vnet gcp 'google_compute_subnetwork.subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/default divyam-pre-prod-defaults.hcl
./sample_deploy.sh import 0-foundation/1-vnet gcp 'google_compute_subnetwork.app_gw_subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/proxy-only-subnet divyam-pre-prod-defaults.hcl

# 0-foundation/2-nat (Cloud Router and NAT)
./sample_deploy.sh import 0-foundation/2-nat gcp 'google_compute_router.egress_nat_router[0]' projects/pre-production-project/regions/asia-south1/routers/egress-nat-router-preprod divyam-pre-prod-defaults.hcl
./sample_deploy.sh import 0-foundation/2-nat gcp 'google_compute_router_nat.nat_config[0]' projects/pre-production-project/regions/asia-south1/routers/egress-nat-router-preprod/egress-nat-config-preprod divyam-pre-prod-defaults.hcl

# 0-foundation/2-terraform_state_blob_storage (GCS state bucket)
./sample_deploy.sh import 0-foundation/2-terraform_state_blob_storage gcp 'google_storage_bucket.terraform[0]' divyamdevtfstate divyam-pre-prod-defaults.hcl

# 1-platform/0-divyam_object_storage (GCS bucket). If the key differs, run in 1-platform/0-divyam_object_storage/gcp: terragrunt output import_keys_created
./sample_deploy.sh import 1-platform/0-divyam_object_storage gcp 'google_storage_bucket.this["divyamdevstorage/divyam-preprod-gcs-router-raw-logs"]' projects/pre-production-project/storage/buckets/divyam-preprod-gcs-router-raw-logs divyam-pre-prod-defaults.hcl

# --- Dev example (values/defaults.hcl, project divyam-dev-rg) ---
# ORG_ID=1060883629618 BILLING_ACCOUNT="01FACA-EFA07C-B3BD77" ./sample_deploy.sh import 0-foundation/0-resource_scope gcp 'google_project.project[0]' divyam-dev-rg values/defaults.hcl
