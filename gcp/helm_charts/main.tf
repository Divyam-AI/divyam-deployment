provider "google" {    
    project = var.project_id
    region  = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets-${var.environment}-ns"
  create_namespace = true

  version = "0.10.5"

  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}

resource "kubernetes_namespace" "divyam_namespaces" {
  for_each = toset(var.namespace_names)

  metadata {
    name = each.key
  }
}
