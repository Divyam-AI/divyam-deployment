# External/Internal Load Balancer (GCP). Config from values/defaults.hcl divyam_load_balancer.
# VNet and subnetwork resolved from values/defaults.hcl vnet.* (no Terragrunt dependency on 1-vnet).

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
  deployment_mode = try(local.root.deployment_mode, "onprem")

  create_public_lb     = try(local.lb_cfg.public, false)
  tls_enabled          = try(local.lb_cfg.tls_enabled, false)
  create_ssl_cert      = try(local.lb_cfg.create_ssl_cert, false)
  create_ip            = try(local.lb_cfg.create_ip, true)
  lb_ip                = try(local.lb_cfg.ip, null)
  lb_ip_name           = try(local.lb_cfg.public_ip_name, null)
  ssl_cert_name        = try(local.lb_cfg.ssl_cert_name, null)
  router_dns           = try(local.lb_cfg.router_dns, "")
  dashboard_dns        = try(local.lb_cfg.dashboard_dns, "")
  controlplane_dns     = local.deployment_mode == "managed" ? try(local.lb_cfg.controlplane_dns, "") : ""
  backend_service_name = try(local.lb_cfg.backend_service_name, "${local.root.deployment_prefix}-lb")
  target_proxy_name    = try(local.lb_cfg.target_proxy_name, "${local.root.deployment_prefix}-proxy")

  project_id   = local.root.resource_scope.name
  region       = local.root.region
  # From vnet config (defaults.hcl) only — no constructed URLs; Terraform builds/fetches from these names.
  network_name        = try(local.vnet.name, "default")
  app_gw_subnet_name  = try(local.vnet.app_gw_subnet.name, null)

  static_ip_name       = local.create_public_lb ? coalesce(local.lb_ip_name, "${local.backend_service_name}-ip") : null
  private_ip_name      = try(local.lb_cfg.private_ip_name, null)
  create_public_ip     = try(local.lb_cfg.create_public_ip, true)
  waf_enabled          = try(local.lb_cfg.waf_enabled, true)
  create_waf           = try(local.lb_cfg.create_waf, true)
  waf_policy_name      = try(local.lb_cfg.waf_policy_name, null)
  waf_deny_ip_ranges   = try(local.lb_cfg.waf_deny_ip_ranges, [])
  waf_allow_ip_ranges  = try(local.lb_cfg.waf_allow_ip_ranges, [])
  cloud_armor_policy_id = null
  ssl_cert_id          = null
  lb_enabled           = try(local.lb_cfg.enabled, true)
}

inputs = {
  common_tags          = try(local.root.common_tags, {})
  tag_globals          = try(include.root.inputs.tag_globals, {})
  tag_context          = try(include.root.inputs.tag_context, { resource_name = local.backend_service_name })

  project_id            = local.project_id
  region                = local.region
  create_public_lb      = local.create_public_lb
  tls_enabled           = local.tls_enabled
  lb_ip                 = local.lb_ip
  ssl_certificate_id    = local.ssl_cert_id
  create_ssl_cert       = local.create_ssl_cert
  ssl_cert_name         = local.ssl_cert_name
  router_dns            = local.router_dns
  dashboard_dns         = local.dashboard_dns
  controlplane_dns      = local.controlplane_dns
  deployment_mode       = local.deployment_mode
  lb_enabled            = local.lb_enabled
  static_ip_name        = local.static_ip_name
  private_ip_name   = local.private_ip_name
  create_public_ip       = local.create_public_ip
  waf_enabled            = local.waf_enabled
  create_waf             = local.create_waf
  waf_policy_name        = local.waf_policy_name
  waf_deny_ip_ranges     = local.waf_deny_ip_ranges
  waf_allow_ip_ranges    = local.waf_allow_ip_ranges
  cloud_armor_policy_id  = local.cloud_armor_policy_id
  backend_service_name   = local.backend_service_name
  target_proxy_name     = local.target_proxy_name
  gke_neg_names         = []
  gke_neg_zones         = []
  network_name          = local.network_name
  app_gw_subnet_name    = local.app_gw_subnet_name
}
