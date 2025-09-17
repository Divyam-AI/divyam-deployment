output "load_balancer_ip" {
  description = "IP address of the Application Gateway (Public or Private)"
  value       = var.create_public_lb ? azurerm_public_ip.lb_ip[0].ip_address : azurerm_application_gateway.appgw.frontend_ip_configuration[0].private_ip_address
}

output "load_balancer_type" {
  description = "Type of Application Gateway deployment"
  value       = var.create_public_lb ? "External Application Gateway" : "Internal Application Gateway"
}

output "load_balancer_redirects_http_to_https" {
  description = "True if HTTP traffic is redirected to HTTPS"
  value       = var.tls_enabled != null
}

output "app_gateway_name" {
  description = "Application Gateway Name"
  value       = azurerm_application_gateway.appgw.name
}

output "app_gateway_tls_enabled" {
  description = "Indicates if TLS is enabled at Application Gateway"
  value       = var.tls_enabled
}

output "app_gateway_certificate_name" {
  description = "TLS certificate name if tls is enabled, else null"
  value       = var.certificate_secret_id != null ? "${var.backend_service_name}-cert" : null
}

output "app_gateway_id" {
  description = "Application Gateway ID"
  value       = azurerm_application_gateway.appgw.id
}

output "agic_identity_client_id" {
  description = "Client ID of the AGIC Managed Identity"
  value       = azurerm_user_assigned_identity.agic_identity.client_id
}

output "agic_identity_id" {
  description = "Resource ID of the AGIC Managed Identity"
  value       = azurerm_user_assigned_identity.agic_identity.id
}

output "appgw_id" {
  description = "Resource ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.id
}
