locals {
  artifacts_preprocessed = yamldecode(file(var.artifacts_path))

  filtered_charts = [
    # Filter out excluded charts.
    for chart_name, chart in local.artifacts_preprocessed["helm_charts"] :
    { chart_name = chart_name, chart = chart }
    if !(contains(var.exclude_charts, chart_name))
  ]

  # The chart information.
  charts = { for pair in local.filtered_charts : pair.chart_name => pair.chart }

  namespaces = toset([
    for chart in local.charts : (
      lookup(chart, "namespace", null) != null ? chart["namespace"] : "${chart["namespace_prefix"]}-${var.environment}-ns"
    )
  ])

  new_namespaces = toset([
    for ns in local.namespaces : ns
    if ns != "kube-system"
  ])
}

provider "kubernetes" {
  host                   = var.aks_kube_config[var.aks_cluster_name].host
  client_certificate     = base64decode(var.aks_kube_config[var.aks_cluster_name].client_certificate)
  client_key             = base64decode(var.aks_kube_config[var.aks_cluster_name].client_key)
  cluster_ca_certificate = base64decode(var.aks_kube_config[var.aks_cluster_name].cluster_ca_certificate)
}

# Create the namespaces
resource "kubernetes_namespace" "divyam_namespaces" {
  for_each = local.new_namespaces

  metadata {
    name = each.key
  }
}

# Read the GAR SA key.
data "azurerm_key_vault_secret" "gar_sa_key" {
  name         = "divyam-gar-sa-key"
  key_vault_id = var.azure_key_vault_id
}

resource "kubernetes_secret" "gar_sa_key" {
  depends_on = [kubernetes_namespace.divyam_namespaces]
  for_each   = toset(local.namespaces)

  metadata {
    name      = "divyam-gar-sa-key"
    namespace = each.value
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.divyam_docker_registry_url) = {
          username = "_json_key"
          password = data.azurerm_key_vault_secret.gar_sa_key.value
          auth     = base64encode("_json_key:${data.azurerm_key_vault_secret.gar_sa_key.value}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}

# Patch default service account in all namespaces to use this as image pull secret.
resource "kubernetes_default_service_account" "default_sa_patch" {
  depends_on = [kubernetes_namespace.divyam_namespaces, kubernetes_secret.gar_sa_key]
  for_each   = toset(local.namespaces)
  metadata {
    namespace = each.value
    annotations = {
      #"azure.workload.identity/client-id" = azurerm_user_assigned_identity.ci_cd.client_id
    }
  }

  image_pull_secret {
    name = "divyam-gar-sa-key"
  }

  lifecycle {
    ignore_changes = [metadata] # Prevent Terraform from resetting managed-by fields
  }
}
