./sample_deploy.sh import 0 gcp 0-resource_scope 'google_project.project[0]' pre-production-project
./sample_deploy.sh import 0 gcp 1-apis google_project_service.enabled_apis pre-production-project divyam-pre-prod-defaults.hcl
./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_network.vpc[0]' projects/pre-production-project/global/networks/default
./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_subnetwork.subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/default
./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_subnetwork.app_gw_subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/default-app-gw