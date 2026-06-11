# Custom K8s: kubeconfig auth only. Datadog install is in ../common (generated common_module.tf).
# required_providers for kubernetes/helm/kubectl are merged via Terragrunt-generated zz_datadog_k8s_override.tf.

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

provider "kubectl" {
  config_path      = var.kubeconfig_path
  load_config_file = true
}
