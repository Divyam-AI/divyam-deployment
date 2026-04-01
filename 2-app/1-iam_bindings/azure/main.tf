############################################
# Data Sources
############################################

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "selected" {
  name = var.resource_group_name
}

# Look up router-requests-logs storage account in Azure by name (from defaults.hcl).
data "azurerm_storage_account" "router_logs" {
  count                = (var.router_logs_storage_account_name != null && var.router_logs_storage_account_name != "") ? 1 : 0
  name                 = var.router_logs_storage_account_name
  resource_group_name  = var.resource_group_name
}

# Look up AKS cluster in Azure by name (from defaults.hcl k8s.name) to get OIDC issuer URL.
data "azurerm_kubernetes_cluster" "aks" {
  count               = (var.aks_cluster_name != null && var.aks_cluster_name != "") ? 1 : 0
  name                = var.aks_cluster_name
  resource_group_name = var.resource_group_name
}

locals {
  router_logs_storage_account_id = (var.router_logs_storage_account_name != null && var.router_logs_storage_account_name != "") ? data.azurerm_storage_account.router_logs[0].id : var.router_logs_storage_account_id
  aks_oidc_issuer_url           = (var.aks_cluster_name != null && var.aks_cluster_name != "" && length(data.azurerm_kubernetes_cluster.aks) > 0) ? data.azurerm_kubernetes_cluster.aks[0].oidc_issuer_url : null
}

############################################
# Service Accounts (shared common module)
############################################

module "service_accounts" {
  source   = "../common"
  env_name = var.env_name
}

############################################
# Locals (derived from common module + azure_iam_role_mapping.tf)
############################################

locals {

  service_accounts = module.service_accounts.service_accounts

  service_account_ids = toset(keys(local.service_accounts))

  scope_ids = {
    resource_group  = data.azurerm_resource_group.selected.id
    storage_account = local.router_logs_storage_account_id
    key_vault       = var.azure_key_vault_id
  }

  sa_role_assignments = flatten([
    for sa_name, sa in local.service_accounts : [
      for role in sa.roles : {
        sa_name = sa_name
        role    = role
      }
    ]
  ])

  valid_role_assignments = [
    for pair in local.sa_role_assignments :
    pair if lookup(local.role_mapping, pair.role, null) != null
  ]

  role_assignments_flat = flatten([
    for pair in local.valid_role_assignments : [
      for ra in local.role_mapping[pair.role].role_assignments : {
        sa_name              = pair.sa_name
        scope                = ra.scope
        role_definition_name = ra.role_definition_name
      }
    ]
  ])

  # Exclude storage_account scope when storage account ID is not available (name not in defaults or lookup failed).
  role_assignments_flat_filtered = [
    for ra in local.role_assignments_flat :
    ra if ra.scope != "storage_account" || local.router_logs_storage_account_id != null
  ]

  _sep = "::"

  role_assignment_keys = toset([
    for ra in local.role_assignments_flat_filtered :
    "${ra.sa_name}${local._sep}${ra.scope}${local._sep}${ra.role_definition_name}"
  ])

  role_assignment_map = {
    for key in local.role_assignment_keys :
    key => {
      sa_name              = split(local._sep, key)[0]
      scope                = split(local._sep, key)[1]
      role_definition_name = split(local._sep, key)[2]
    }
  }

  sa_key_vault_policies = {
    for sa_name in local.service_account_ids :
    sa_name => distinct(flatten([
      for role in local.service_accounts[sa_name].roles :
      try(local.role_mapping[role].key_vault_access_policy.secret_permissions, [])
    ]))
    if length(distinct(flatten([
      for role in local.service_accounts[sa_name].roles :
      try(local.role_mapping[role].key_vault_access_policy.secret_permissions, [])
    ]))) > 0
  }

  federated_identities = local.aks_oidc_issuer_url != null ? {
    for sa_name, sa in local.service_accounts :
    sa_name => {
      namespace       = sa.namespace
      service_account = sa_name
      issuer          = local.aks_oidc_issuer_url
    }
  } : {}

  name_prefix   = coalesce(var.aks_cluster_name, "aks")
  uai_display_name = {
    for sa_name in local.service_account_ids :
    sa_name => "${local.name_prefix}-${replace(sa_name, "_", "-")}-uai"
  }
  tag_context_base = merge(var.tag_globals, var.tag_context)
  # Per-resource tags so each User Assigned Identity gets its name in tags.
  rendered_tags_for_uai = {
    for sa_name in local.service_account_ids :
    sa_name => {
      for k, v in var.common_tags :
      k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.uai_display_name[sa_name] }), try(regex("#\\{([^}]+)\\}", v)[0], ""), ""))
    }
  }
}

############################################
# User Assigned Identities
############################################

resource "azurerm_user_assigned_identity" "identities" {
  for_each            = local.service_account_ids
  name                = local.uai_display_name[each.key]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = local.rendered_tags_for_uai[each.key]
}

############################################
# Role Assignments
############################################

resource "azurerm_role_assignment" "role_assignments" {
  for_each             = local.role_assignment_map
  scope                = local.scope_ids[each.value.scope]
  role_definition_name = each.value.role_definition_name
  principal_id         = azurerm_user_assigned_identity.identities[each.value.sa_name].principal_id

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

############################################
# Key Vault Access Policies
############################################

resource "azurerm_key_vault_access_policy" "identities" {
  for_each     = local.sa_key_vault_policies
  key_vault_id = var.azure_key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.identities[each.key].principal_id

  secret_permissions = each.value
}

############################################
# Federated Identity Credentials (K8s SA → UAI)
############################################

resource "azurerm_federated_identity_credential" "k8s_federation" {
  for_each = local.federated_identities

  name                = "${each.key}-k8s-workload"
  parent_id           = azurerm_user_assigned_identity.identities[each.key].id

  audience = ["api://AzureADTokenExchange"]
  issuer   = each.value.issuer

  subject = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}
