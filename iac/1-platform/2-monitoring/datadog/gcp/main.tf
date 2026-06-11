# GCP root: google provider for cluster API token; kubernetes/helm target GKE. Datadog install is in ../common (generated common_module.tf).
# required_providers for kubernetes/helm are merged via Terragrunt-generated *_override.tf (root already emits
# provider.tf with google only — do not add a second terraform {} here).

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "current" {}

provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = "https://${var.cluster_endpoint}"
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  load_config_file       = false
}
