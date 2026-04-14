output "load_balancer_ip" {
  description = "IP address of the Application Gateway (Public or Private)"
  value       = var.create_public_lb ? local.public_ip_address : azurerm_application_gateway.appgw.frontend_ip_configuration[0].private_ip_address
}

output "load_balancer_type" {
  description = "Type of Application Gateway deployment"
  value       = var.create_public_lb ? "External Application Gateway" : "Internal Application Gateway"
}

output "load_balancer_redirects_http_to_https" {
  description = "True if HTTP traffic is redirected to HTTPS"
  value       = var.tls_enabled
}

output "app_gateway_name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.appgw.name
}

output "app_gateway_tls_enabled" {
  description = "Whether TLS is enabled at Application Gateway"
  value       = var.tls_enabled
}

output "app_gateway_certificate_name" {
  description = "TLS certificate name if TLS is enabled, else null"
  value       = (var.tls_enabled && (var.certificate_secret_id != null || (var.create_ssl_cert && length(azurerm_key_vault_certificate.cert) > 0))) ? "${var.backend_service_name}-cert" : null
}

output "certificate_secret_id" {
  description = "Key Vault secret ID of the TLS certificate when create_ssl_cert is true."
  value       = var.create_ssl_cert && length(azurerm_key_vault_certificate.cert) > 0 ? azurerm_key_vault_certificate.cert[0].secret_id : null
}

output "certificate_thumbprint" {
  description = "Thumbprint of the TLS certificate when create_ssl_cert is true."
  value       = var.create_ssl_cert && length(azurerm_key_vault_certificate.cert) > 0 ? azurerm_key_vault_certificate.cert[0].thumbprint : null
}

output "app_gateway_id" {
  description = "Application Gateway ID"
  value       = azurerm_application_gateway.appgw.id
}

output "agic_identity_client_id" {
  description = "Client ID of the AGIC managed identity"
  value       = azurerm_user_assigned_identity.agic_identity.client_id
}

output "agic_identity_id" {
  description = "Resource ID of the AGIC managed identity"
  value       = azurerm_user_assigned_identity.agic_identity.id
}

output "agic_identity_principal_id" {
  description = "Principal ID of the AGIC managed identity"
  value       = azurerm_user_assigned_identity.agic_identity.principal_id
}

output "appgw_id" {
  description = "Resource ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.id
}

output "gateway_subnet_id" {
  description = "Subnet ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.gateway_ip_configuration[0].subnet_id
}

output "waf_policy_id" {
  description = "WAF policy ID when waf_enabled (created in-module or fetched by name)"
  value       = local.waf_policy_id
}

output "router_dns_zone" {
  description = "API FQDN derived from private DNS zone and dns_records.api."
  value       = trimspace(coalesce(var.private_dns_zone_name, "")) != "" && trimspace(var.api_dns_record_name) != "" ? "${trimspace(var.api_dns_record_name)}.${trimspace(var.private_dns_zone_name)}" : null
}

output "dashboard_dns_zone" {
  description = "Dashboard FQDN derived from private DNS zone and dns_records.dashboard."
  value       = trimspace(coalesce(var.private_dns_zone_name, "")) != "" && trimspace(var.dashboard_dns_record_name) != "" ? "${trimspace(var.dashboard_dns_record_name)}.${trimspace(var.private_dns_zone_name)}" : null
}

output "controlplane_dns_zone" {
  description = "Control-plane FQDN derived from private DNS zone and dns_records.controlplane."
  value       = trimspace(coalesce(var.private_dns_zone_name, "")) != "" && trimspace(var.controlplane_dns_record_name) != "" ? "${trimspace(var.controlplane_dns_record_name)}.${trimspace(var.private_dns_zone_name)}" : null
}
