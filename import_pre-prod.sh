./sample_deploy.sh import 0 gcp 0-resource_scope 'google_project.project[0]' pre-production-project
./sample_deploy.sh import 0 gcp 1-apis google_project_service.enabled_apis pre-production-project divyam-pre-prod-defaults.hcl
./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_network.vpc[0]' projects/pre-production-project/global/networks/default
./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_subnetwork.subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/default
./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_subnetwork.app_gw_subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/proxy-only-subnet
./sample_deploy.sh import 0 gcp 2-nat 'google_compute_router.egress_nat_router[0]' projects/pre-production-project/regions/asia-south1/routers/egress-nat-router-preprod
./sample_deploy.sh import 0 gcp 2-nat 'google_compute_router_nat.nat_config[0]' projects/pre-production-project/regions/asia-south1/routers/egress-nat-router-preprod/egress-nat-config-preprod
./sample_deploy.sh import 0 gcp 2-terraform_state_blob_storage 'google_storage_bucket.terraform[0]' divyamdevtfstate
# Import existing GCS bucket into state so Terraform does not try to create it. Use same VALUES_FILE as plan.
# Ensure state is in backend: run without TG_USE_LOCAL_BACKEND=1 (or set TG_USE_LOCAL_BACKEND=0).
# If the key differs, run in 1-platform/0-divyam_object_storage/gcp: terragrunt output import_keys_created
./sample_deploy.sh import 1 gcp 0-divyam_object_storage 'google_storage_bucket.this["divyamdevstorage/divyam-preprod-gcs-router-raw-logs"]' projects/pre-production-project/storage/buckets/divyam-preprod-gcs-router-raw-logs divyam-pre-prod-defaults.hcl


ORG_ID=1060883629618 BILLING_ACCOUNT="01FACA-EFA07C-B3BD77" ./sample_deploy.sh import 0-foundation/0-resource_scope gcp 'google_project.project[0]' divyam-dev-rg values/defaults.hcl
