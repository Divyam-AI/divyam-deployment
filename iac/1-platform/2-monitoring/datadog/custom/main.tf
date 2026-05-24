# Datadog on a custom Kubernetes cluster. Cluster API auth comes from kubeconfig_path only
# (set KUBECONFIG on the host). Does not use GKE/AKS tokens from 1-k8s.

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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "kubectl" {
  config_path      = var.kubeconfig_path
  load_config_file = true
}

module "datadog_k8s" {
  source = "../common"

  datadog_enabled         = var.datadog_enabled
  cluster_name            = var.cluster_name
  datadog_site            = var.datadog_site
  datadog_env             = var.datadog_env
  datadog_api_key         = var.datadog_api_key
  datadog_docker_registry = var.datadog_docker_registry

  datadog_exclude_namespaces         = var.datadog_exclude_namespaces
  datadog_exclude_namespaces_logs    = var.datadog_exclude_namespaces_logs
  datadog_exclude_namespaces_metrics = var.datadog_exclude_namespaces_metrics
  divyam_clickhouse_password         = var.divyam_clickhouse_password
  divyam_db_password                 = var.divyam_db_password
}
