# Application Gateway (Azure). Config from values/defaults.hcl divyam_load_balancer.
# VNet and Key Vault are resolved by name from values/defaults.hcl (vnet.*, divyam_secrets.store_name).
# When create_ssl_cert is true, TLS certificate is created in Key Vault (router_dns/dashboard_dns from divyam_load_balancer).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

locals {
  root  = include.root.locals.merged
  lb_cfg = try(local.root.divyam_load_balancer, {})
  vnet   = try(local.root.vnet, {})
  secrets_cfg = try(local.root.divyam_secrets, {})

  create_public_lb     = try(local.lb_cfg.public, false)
  tls_enabled          = try(local.lb_cfg.tls_enabled, false)
  create_ssl_cert      = try(local.lb_cfg.create_ssl_cert, false)
  waf_enabled          = try(local.lb_cfg.waf_enabled, true)
  create_waf           = try(local.lb_cfg.create_waf, true)
  waf_policy_name      = try(local.lb_cfg.waf_policy_name, null)
  waf_deny_ip_ranges   = try(local.lb_cfg.waf_deny_ip_ranges, [])
  waf_allow_ip_ranges  = try(local.lb_cfg.waf_allow_ip_ranges, [])
  create_ip            = try(local.lb_cfg.create_ip, true)
  lb_ip                = try(local.lb_cfg.ip, null)
  lb_ip_name           = try(local.lb_cfg.public_ip_name, null)
  create_public_ip   = try(local.lb_cfg.create_public_ip, true)
  backend_service_name = try(local.lb_cfg.backend_service_name, "${local.root.deployment_prefix}-appgw")
  ssl_cert_name        = try(local.lb_cfg.ssl_cert_name, "${local.root.deployment_prefix}-lb-ssl-cert")

  vnet_name                = try(local.vnet.name, "")
  vnet_resource_group_name = try(local.vnet.scope_name, local.root.resource_scope.name)
  vnet_subnet_name         = try(local.vnet.app_gw_subnet.name, "")
  key_vault_name           = try(local.secrets_cfg.store_name, "")
  router_dns_zone          = try(local.lb_cfg.router_dns, "")
  dashboard_dns_zone       = try(local.lb_cfg.dashboard_dns, "")
  controlplane_dns_zone    = try(local.lb_cfg.controlplane_dns, "")
  create_dns_records       = try(local.lb_cfg.create_dns_records, true)
  lb_enabled               = try(local.lb_cfg.enabled, true)
  gateway_sku              = try(local.lb_cfg.gateway_sku, "WAF_v2")
}

inputs = {
  environment          = local.root.env_name
  common_tags          = try(local.root.common_tags, {})
  tag_globals          = try(include.root.inputs.tag_globals, {})
  tag_context          = try(include.root.inputs.tag_context, { resource_name = local.backend_service_name })

  backend_service_name       = local.backend_service_name
  create_public_lb           = local.create_public_lb
  create_ip                  = local.create_ip
  lb_ip                      = local.lb_ip
  lb_ip_name                 = local.lb_ip_name
  create_public_ip     = local.create_public_ip
  tls_enabled          = local.tls_enabled
  waf_enabled                = local.waf_enabled
  create_waf                 = local.create_waf
  waf_policy_name            = local.waf_policy_name
  waf_deny_ip_ranges         = local.waf_deny_ip_ranges
  waf_allow_ip_ranges        = local.waf_allow_ip_ranges
  gateway_sku                = local.gateway_sku
  create_ssl_cert            = local.create_ssl_cert
  location                   = local.root.region
  resource_group_name        = local.root.resource_scope.name

  vnet_name                 = local.vnet_name
  vnet_resource_group_name  = local.vnet_resource_group_name
  subnet_ids                = {}
  vnet_subnet_name          = local.vnet_subnet_name

  certificate_secret_id = null
  azure_key_vault_id    = null  # Resolved by module from azure_key_vault_name (divyam_secrets.store_name) via data source
  azure_key_vault_name  = local.key_vault_name

  cert_name           = local.ssl_cert_name
  router_dns_zone     = local.router_dns_zone
  dashboard_dns_zone  = local.dashboard_dns_zone
  controlplane_dns_zone = local.controlplane_dns_zone
  create_dns_records  = local.create_dns_records
}

exclude {
  if      = !local.lb_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
