locals {
  release_name = coalesce(var.release_name, "${var.cluster_name}-ingress-azure")
}

data "azurerm_resource_group" "selected" {
  name = var.resource_group_name
}

provider "helm" {
  kubernetes = {
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
  }
}

resource "azurerm_role_assignment" "agic_appgw_access" {
  scope                = var.app_gateway_id
  role_definition_name = "Contributor"
  principal_id         = var.agic_identity_principal_id
}

resource "azurerm_role_assignment" "agic_subnet_permissions" {
  scope                = var.gateway_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = var.agic_identity_principal_id
}

resource "azurerm_role_assignment" "resource_group_reader" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Reader"
  principal_id         = var.agic_identity_principal_id
}

resource "azurerm_role_assignment" "agic_identity_assigner" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = var.agic_identity_principal_id
}

resource "azurerm_federated_identity_credential" "agic" {
  name                = "${var.cluster_name}-agic-fic"
  resource_group_name = var.resource_group_name
  parent_id           = var.agic_identity_id
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${local.release_name}"
  audience            = ["api://AzureADTokenExchange"]
}

resource "helm_release" "agic" {
  name       = local.release_name
  repository = "oci://mcr.microsoft.com/azure-application-gateway/charts/"
  chart      = "ingress-azure"
  namespace  = var.namespace
  version    = var.agic_helm_version

  replace = true

  set = [
    {
      name  = "appgw.resourceGroup"
      value = var.resource_group_name
    },
    {
      name  = "appgw.name"
      value = var.app_gateway_name
    },
    {
      name  = "armAuth.type"
      value = "workloadIdentity"
    },
    {
      name  = "armAuth.identityResourceID"
      value = var.agic_identity_id
    },
    {
      name  = "armAuth.identityClientID"
      value = var.agic_identity_client_id
    },
    {
      name  = "rbac.enabled"
      value = "true"
    },
    {
      name  = "verbosityLevel"
      value = tostring(var.verbosity_level)
    }
  ]

  depends_on = [
    azurerm_role_assignment.agic_appgw_access,
    azurerm_role_assignment.agic_subnet_permissions,
    azurerm_role_assignment.resource_group_reader,
    azurerm_role_assignment.agic_identity_assigner,
    azurerm_federated_identity_credential.agic,
  ]
}
