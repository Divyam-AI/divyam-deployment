terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    # DatadogAgent CRD is registered by the operator Helm chart; hashicorp/kubernetes_manifest
    # validates against the live API at plan time and fails before the chart is applied.
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}
