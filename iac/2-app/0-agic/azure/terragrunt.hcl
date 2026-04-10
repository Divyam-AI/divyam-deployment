# AGIC (Application Gateway Ingress Controller) deployment for Azure.
# Installs ingress-azure via Terraform Helm provider and configures workload identity federation.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "k8s" {
  config_path = "../../../1-platform/1-k8s/azure"
  mock_outputs = {
    aks_cluster_name = "mock-aks-cluster"
    aks_oidc_issuer_url = "https://mock-issuer/"
    aks_kube_config = {
      host                   = "https://mock-aks-cluster"
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "app_gw" {
  config_path = "../../../1-platform/0-app_gw/azure"
  mock_outputs = {
    app_gateway_name          = "mock-appgw"
    app_gateway_id            = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/applicationGateways/mock-appgw"
    gateway_subnet_id         = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock-appgw-subnet"
    agic_identity_id          = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock-agic-id"
    agic_identity_client_id   = "00000000-0000-0000-0000-000000000000"
    agic_identity_principal_id = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root      = include.root.locals.merged
  agic_cfg  = try(local.root.agic, {})
  lb_cfg    = try(local.root.divyam_load_balancer, {})

  agic_enabled = try(local.agic_cfg.enabled, false)
  lb_enabled   = try(local.lb_cfg.enabled, true)
}

inputs = {
  resource_group_name = local.root.resource_scope.name
  cluster_name        = dependency.k8s.outputs.aks_cluster_name
  aks_oidc_issuer_url = dependency.k8s.outputs.aks_oidc_issuer_url
  kube_config         = dependency.k8s.outputs.aks_kube_config

  app_gateway_name         = dependency.app_gw.outputs.app_gateway_name
  app_gateway_id           = dependency.app_gw.outputs.app_gateway_id
  gateway_subnet_id        = dependency.app_gw.outputs.gateway_subnet_id
  agic_identity_id         = dependency.app_gw.outputs.agic_identity_id
  agic_identity_client_id  = dependency.app_gw.outputs.agic_identity_client_id
  agic_identity_principal_id = dependency.app_gw.outputs.agic_identity_principal_id

  agic_helm_version = try(local.agic_cfg.helm_chart_version, "1.8.1")
  namespace         = try(local.agic_cfg.namespace, "kube-system")
  release_name      = try(local.agic_cfg.release_name, null)
  verbosity_level   = try(local.agic_cfg.verbosity_level, 3)
}

exclude {
  if      = !local.agic_enabled || !local.lb_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
