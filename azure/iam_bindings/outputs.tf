# User-Assigned Identity Outputs
output "uai_client_ids" {
  description = "A map from name to UAI client IDs."
  sensitive   = true
  value = {
    prometheus_uai_client_id        = azurerm_user_assigned_identity.prometheus.client_id
    kafka_connect_uai_client_id     = azurerm_user_assigned_identity.kafka_connect.client_id
    billing_uai_client_id           = azurerm_user_assigned_identity.billing.client_id
    router_controller_uai_client_id = azurerm_user_assigned_identity.router_controller.client_id
    eval_uai_client_id              = azurerm_user_assigned_identity.eval.client_id
    selector_training_uai_client_id = azurerm_user_assigned_identity.selector_training.client_id
  }
}

# Outputs for User Assigned Identities (UAI)
output "prometheus_uai_id" {
  description = "The ID of the Prometheus User Assigned Identity"
  value       = azurerm_user_assigned_identity.prometheus.id
}

output "kafka_connect_uai_id" {
  description = "The ID of the Kafka Connect User Assigned Identity"
  value       = azurerm_user_assigned_identity.kafka_connect.id
}

output "billing_uai_id" {
  description = "The ID of the Billing User Assigned Identity"
  value       = azurerm_user_assigned_identity.billing.id
}

output "router_controller_uai_id" {
  description = "The ID of the Router Controller User Assigned Identity"
  value       = azurerm_user_assigned_identity.router_controller.id
}

output "eval_uai_id" {
  description = "The ID of the Eval User Assigned Identity"
  value       = azurerm_user_assigned_identity.eval.id
}

output "selector_training_uai_id" {
  description = "The ID of the Selector Training User Assigned Identity"
  value       = azurerm_user_assigned_identity.selector_training.id
}

# Outputs for Role Assignments

output "prometheus_monitoring_metrics_role_assignment" {
  description = "The ID of the role assignment for Prometheus monitoring metrics"
  value       = azurerm_role_assignment.prometheus_monitoring_metrics.id
}

output "kafka_storage_admin_role_assignment" {
  description = "The ID of the role assignment for Kafka Connect storage admin"
  value       = azurerm_role_assignment.kafka_storage_admin.id
}

output "billing_storage_reader_role_assignment" {
  description = "The ID of the role assignment for Billing storage reader"
  value       = azurerm_role_assignment.billing_storage_reader.id
}

output "billing_key_vault_role_assignment" {
  description = "The ID of the role assignment for Billing Key Vault user"
  value       = azurerm_role_assignment.billing_key_vault.id
}

output "router_controller_reader_role_assignment" {
  description = "The ID of the role assignment for Router Controller reader"
  value       = azurerm_role_assignment.router_controller_reader.id
}

output "router_controller_key_vault_access_role_assignment" {
  description = "The ID of the role assignment for Router Controller Key Vault access"
  value       = azurerm_role_assignment.router_controller_key_vault.id
}

output "eval_key_vault_role_assignment" {
  description = "The ID of the role assignment for Eval Key Vault user"
  value       = azurerm_role_assignment.eval_key_vault.id
}

output "selector_training_key_vault_role_assignment" {
  description = "The ID of the role assignment for Selector Training Key Vault user"
  value       = azurerm_role_assignment.selector_training_key_vault.id
}

output "selector_training_storage_admin_role_assignment" {
  description = "The ID of the role assignment for Selector Training storage admin"
  value       = azurerm_role_assignment.selector_training_storage_admin.id
}
