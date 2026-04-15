# Azure root: configures kubernetes/helm for AKS; Datadog install lives in ../common (see common_module.tf).
# required_providers for kubernetes/helm are merged via Terragrunt-generated *_override.tf (root already emits
# provider.tf with azurerm only — a second terraform {} here duplicates that block and breaks tofu init).

provider "kubernetes" {
  host                   = var.kube_config.host
  client_certificate     = base64decode(var.kube_config.client_certificate)
  client_key             = base64decode(var.kube_config.client_key)
  cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
  }
}
