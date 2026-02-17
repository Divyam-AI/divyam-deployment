locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }

  artifacts_preprocessed = yamldecode(file(var.artifacts_path))

  filtered_charts = [
    # Filter out excluded charts.
    for chart_name, chart in local.artifacts_preprocessed["helm_charts"] :
    { chart_name = chart_name, chart = chart }
    if !(contains(var.exclude_charts, chart_name))
  ]

  name_prefix = var.aks_cluster_name

  # The chart information.
  charts = { for pair in local.filtered_charts : pair.chart_name => pair.chart }

  # Convert the filtered map from UAI name to a list of {oidc_issuer_url, namespace,
  # service account} objects creating federated identity credentials.
  identity_maps = flatten([
    for chart_name, chart in local.charts : (
      lookup(chart, "uai_client_id_name", null) != null && lookup(chart, "uai_federated_ksa_pattern", null) != null ?
      [{
        key = chart.uai_client_id_name
        value = {
          oidc_issuer_url = var.aks_oidc_issuer_url
          namespace       = lookup(chart, "namespace", null) != null ? chart["namespace"] : "${chart["namespace_prefix"]}-${var.environment}-ns"
          service_account = replace(chart.uai_federated_ksa_pattern, "$${env}", var.environment)
        }
      }] :
      []
    )
  ])

  federated_identity_grouped_temp = {
    for k in toset([for i in local.identity_maps : i.key]) :
    k => [
      for i in local.identity_maps : i.value if i.key == k
    ]
  }

  federated_identity_grouped = {
    for k, v in local.federated_identity_grouped_temp : k => {
      for o in v : "${var.aks_cluster_name}-${o.namespace}-${o.service_account}" => o
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "selected" {
  name = var.resource_group_name
}

# -----------------------------------------------
# Prometheus Metric Writer IAM Setup
# -----------------------------------------------

resource "azurerm_user_assigned_identity" "prometheus" {
  name                = "${local.name_prefix}-prometheus-uai"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${local.name_prefix}-prometheus-uai"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_role_assignment" "prometheus_monitoring_metrics" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.prometheus.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_federated_identity_credential" "prometheus_k8s_federation" {
  for_each            = lookup(local.federated_identity_grouped, "prometheus_uai_client_id", {})
  name                = "${each.key}-k8s-workload"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.prometheus.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}


# -----------------------------------------------
# Kafka Connect IAM Setup
# -----------------------------------------------

resource "azurerm_user_assigned_identity" "kafka_connect" {
  name                = "${local.name_prefix}-kafka-connect-uai"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${local.name_prefix}-kafka-connect-uai"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_role_assignment" "kafka_storage_admin" {
  scope                = var.router_logs_storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.kafka_connect.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_federated_identity_credential" "kafka_connect_k8s_federation" {
  for_each            = lookup(local.federated_identity_grouped, "kafka_connect_uai_client_id", {})
  name                = "${each.key}-k8s-workload"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.kafka_connect.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}

# -----------------------------------------------
# Billing IAM Setup
# -----------------------------------------------

resource "azurerm_user_assigned_identity" "billing" {
  name                = "${local.name_prefix}-billing-uai"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${local.name_prefix}-billing-uai"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_role_assignment" "billing_storage_reader" {
  scope                = var.router_logs_storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.billing.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_role_assignment" "billing_key_vault" {
  scope                = var.azure_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.billing.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_federated_identity_credential" "billing_k8s_federation" {
  for_each            = lookup(local.federated_identity_grouped, "billing_uai_client_id", {})
  name                = "${each.key}-k8s-workload"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.billing.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}

# -----------------------------------------------
# Router Controller IAM Setup
# -----------------------------------------------

resource "azurerm_user_assigned_identity" "router_controller" {
  name                = "${local.name_prefix}-router-controller-uai"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${local.name_prefix}-router-controller-uai"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_role_assignment" "router_controller_reader" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.router_controller.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_role_assignment" "router_controller_key_vault" {
  scope                = var.azure_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.router_controller.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_key_vault_access_policy" "router_controller_key_vault_policy" {
  key_vault_id = var.azure_key_vault_id # The Key Vault ID

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.router_controller.principal_id # Principal ID of the user-assigned identity

  secret_permissions = [
    "Get",
    "List",
    "Set"
  ]
}

resource "azurerm_federated_identity_credential" "router_controller_k8s_federation" {
  for_each            = lookup(local.federated_identity_grouped, "router_controller_uai_client_id", {})
  name                = "${each.key}-k8s-workload"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.router_controller.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}

# -----------------------------------------------
# Eval Job IAM Setup
# -----------------------------------------------

resource "azurerm_user_assigned_identity" "eval" {
  name                = "${local.name_prefix}-eval-uai"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${local.name_prefix}-eval-uai"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_role_assignment" "eval_reader" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.eval.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_role_assignment" "eval_key_vault" {
  scope                = var.azure_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eval.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_key_vault_access_policy" "eval_key_vault_policy" {
  key_vault_id = var.azure_key_vault_id # The Key Vault ID

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.eval.principal_id # Principal ID of the user-assigned identity

  secret_permissions = [
    "Get",
    "List"
  ]
}

resource "azurerm_federated_identity_credential" "eval_k8s_federation" {
  for_each            = lookup(local.federated_identity_grouped, "eval_uai_client_id", {})
  name                = "${each.key}-k8s-workload"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.eval.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}

# -----------------------------------------------
# Selector training IAM Setup
# -----------------------------------------------

resource "azurerm_user_assigned_identity" "selector_training" {
  name                = "${local.name_prefix}-selector-training-uai"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${local.name_prefix}-selector-training-uai"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_role_assignment" "selector_training_key_vault" {
  scope                = var.azure_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.selector_training.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_role_assignment" "selector_training_storage_admin" {
  scope                = var.router_logs_storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.selector_training.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_federated_identity_credential" "selector_training_k8s_federation" {
  for_each            = lookup(local.federated_identity_grouped, "selector_training_uai_client_id", {})
  name                = "${each.key}-k8s-workload"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.selector_training.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}

resource "azurerm_role_assignment" "selector_training_reader" {
  scope                = data.azurerm_resource_group.selected.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.selector_training.principal_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      role_definition_name,
      principal_id,
      scope,
    ]
  }
}

resource "azurerm_key_vault_access_policy" "selector_training_key_vault_policy" {
  key_vault_id = var.azure_key_vault_id # The Key Vault ID

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.selector_training.principal_id # Principal ID of the user-assigned identity

  secret_permissions = [
    "Get",
    "List",
    "Set"
  ]
}
