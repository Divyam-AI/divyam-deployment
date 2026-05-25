# Datadog agent on a custom Kubernetes cluster (kubeconfig on the apply host).
# Does NOT include parent 2-monitoring/terragrunt.hcl — no dependency on 1-k8s.
# Set KUBECONFIG (or default ~/.kube/config) before plan/apply.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

generate "common_module" {
  path      = "common_module.tf"
  if_exists = "overwrite"
  contents  = <<EOF
module "datadog_k8s" {
  source = "${get_terragrunt_dir()}/../common"

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
EOF
}

generate "k8s_providers_override" {
  path      = "zz_datadog_k8s_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
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
EOF
}

locals {
  root            = include.root.locals.merged
  datadog_cfg     = try(local.root.datadog, {})
  datadog_enabled = try(local.datadog_cfg.enabled, false)
  cluster_name = coalesce(
    try(local.datadog_cfg.custom_cluster_name, null),
    try(local.datadog_cfg.sandbox_cluster_name, null), # deprecated alias
    try(local.root.k8s.name, null),
    "custom-k8s"
  )
  kubeconfig_path = coalesce(
    trimspace(get_env("KUBECONFIG", "")),
    "${get_env("HOME", "/root")}/.kube/config"
  )
}

inputs = {
  kubeconfig_path = local.kubeconfig_path
  cluster_name    = local.cluster_name
  datadog_enabled = local.datadog_enabled

  datadog_site            = trimspace(try(local.datadog_cfg.site, "datadoghq.com"))
  datadog_docker_registry = trimspace(try(local.datadog_cfg.docker_registry, "asia.gcr.io/datadoghq"))
  datadog_env             = trimspace(try(local.datadog_cfg.env, try(local.root.env_name, "dev")))

  datadog_exclude_namespaces         = try(local.datadog_cfg.exclude_namespaces, [])
  datadog_exclude_namespaces_logs    = try(local.datadog_cfg.exclude_namespaces_logs, [])
  datadog_exclude_namespaces_metrics = try(local.datadog_cfg.exclude_namespaces_metrics, [])

  datadog_api_key            = get_env("TF_VAR_datadog_api_key", "")
  divyam_clickhouse_password = get_env("TF_VAR_divyam_clickhouse_password", "")
  divyam_db_password         = get_env("TF_VAR_divyam_db_password", "")
}

exclude {
  if      = !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
