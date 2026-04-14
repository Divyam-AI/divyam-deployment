terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}

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

locals {
  datadog_namespace = "datadog"
  datadog_release   = "datadog-operator"
  # Shared exclusions are always applied. Granular exclusions are additive.
  datadog_logs_exclude_namespaces = distinct(concat(var.datadog_exclude_namespaces, var.datadog_exclude_namespaces_logs))
  datadog_metrics_exclude_namespaces = distinct(concat(var.datadog_exclude_namespaces, var.datadog_exclude_namespaces_metrics))

  # Datadog expects space-separated kube_namespace:<name> filters.
  datadog_logs_namespace_excludes    = join(" ", formatlist("kube_namespace:%s", local.datadog_logs_exclude_namespaces))
  datadog_metrics_namespace_excludes = join(" ", formatlist("kube_namespace:%s", local.datadog_metrics_exclude_namespaces))
}

resource "helm_release" "datadog_operator" {
  for_each = var.datadog_enabled ? { "enabled" = true } : {}

  name             = local.datadog_release
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog-operator"
  namespace        = local.datadog_namespace
  create_namespace = true
  timeout          = 600
}

resource "kubernetes_secret" "datadog_secret" {
  for_each = var.datadog_enabled ? { "enabled" = true } : {}

  metadata {
    name      = "datadog-secret"
    namespace = local.datadog_namespace
  }

  data = {
    "api-key" = var.datadog_api_key
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "datadog_agent" {
  for_each = var.datadog_enabled ? { "enabled" = true } : {}

  manifest = {
    apiVersion = "datadoghq.com/v2alpha1"
    kind       = "DatadogAgent"
    metadata = {
      name      = "datadog"
      namespace = local.datadog_namespace
    }
    spec = {
      global = {
        clusterName = var.cluster_name
        site        = var.datadog_site
        credentials = {
          apiSecret = {
            secretName = kubernetes_secret.datadog_secret["enabled"].metadata[0].name
            keyName    = "api-key"
          }
        }
        tags = [
          "env:${var.datadog_env}",
        ]
        containerExcludeLogs    = local.datadog_logs_namespace_excludes
        containerExcludeMetrics = local.datadog_metrics_namespace_excludes
      }
      features = {
        clusterChecks = {
          enabled = true
        }
        orchestratorExplorer = {
          enabled = true
        }
        logCollection = {
          enabled             = true
          containerCollectAll = true
        }
      }
    }
  }

  depends_on = [
    helm_release.datadog_operator,
    kubernetes_secret.datadog_secret,
  ]
}
