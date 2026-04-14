# Application Gateway (Azure). Config from values/defaults.hcl divyam_load_balancer.
# Feature spec from 1-old/app_gw.

data "azurerm_subnet" "appgw" {
  name                 = var.vnet_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  count               = (var.create_dns_records && trimspace(coalesce(var.private_dns_zone_name, "")) != "") ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_virtual_network" "additional_calling_vnets" {
  # Extra consumer/caller VNets configured in values/defaults.hcl -> divyam_load_balancer.dns_additional_calling_vnets.
  for_each = var.create_dns_records && trimspace(coalesce(var.private_dns_zone_name, "")) != "" ? {
    for vnet in var.dns_additional_calling_vnets : "${vnet.resource_group_name}/${vnet.name}" => vnet
  } : {}
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

locals {
  subnet_cidr = data.azurerm_subnet.appgw.address_prefixes[0]
  subnet_size = tonumber(regex(".*\\/(\\d+)$", local.subnet_cidr)[0])
  total_hosts  = pow(2, 32 - local.subnet_size)
  # Build FQDNs used for TLS CN/SAN and output compatibility.
  private_dns_zone_name = trimspace(coalesce(var.private_dns_zone_name, ""))
  api_dns_fqdn = (local.private_dns_zone_name != "" && trimspace(var.api_dns_record_name) != "") ? "${trimspace(var.api_dns_record_name)}.${local.private_dns_zone_name}" : ""
  dashboard_dns_fqdn = (local.private_dns_zone_name != "" && trimspace(var.dashboard_dns_record_name) != "") ? "${trimspace(var.dashboard_dns_record_name)}.${local.private_dns_zone_name}" : ""
  controlplane_dns_fqdn = (local.private_dns_zone_name != "" && trimspace(var.controlplane_dns_record_name) != "") ? "${trimspace(var.controlplane_dns_record_name)}.${local.private_dns_zone_name}" : ""

  resource_names = {
    lb_ip          = coalesce(var.lb_ip_name, "${var.backend_service_name}-public-ip")
    appgw_identity = "${var.backend_service_name}-appgw-uami"
    appgw          = "${var.backend_service_name}-appgw"
    agic_identity  = "${var.backend_service_name}-agic-id"
    cert           = var.cert_name
  }
  rendered_tags_for = {
    for key, resource_name in local.resource_names : key => {
      for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", (lookup(merge(local.tag_context, { resource_name = resource_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")))
    }
  }
}

resource "random_integer" "host_offset" {
  count = (!var.create_public_lb && var.lb_ip == null) ? 1 : 0
  min   = 5
  max   = local.total_hosts - 5
}

locals {
  fixed_private_ip = var.create_public_lb ? null : (
    var.lb_ip != null ? var.lb_ip : cidrhost(local.subnet_cidr, random_integer.host_offset[0].result)
  )
}

resource "azurerm_public_ip" "lb_ip" {
  count               = var.create_public_lb && var.create_public_ip ? 1 : 0
  name                = coalesce(var.lb_ip_name, "${var.backend_service_name}-public-ip")
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.rendered_tags_for["lb_ip"]
}

data "azurerm_public_ip" "existing" {
  count               = var.create_public_lb && !var.create_public_ip ? 1 : 0
  name                = var.lb_ip_name
  resource_group_name = var.resource_group_name
}

locals {
  public_ip_id      = var.create_public_lb ? (var.create_public_ip ? azurerm_public_ip.lb_ip[0].id : data.azurerm_public_ip.existing[0].id) : null
  public_ip_address = var.create_public_lb ? (var.create_public_ip ? azurerm_public_ip.lb_ip[0].ip_address : data.azurerm_public_ip.existing[0].ip_address) : null
}

resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = "${var.backend_service_name}-appgw-uami"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.rendered_tags_for["appgw_identity"]
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.backend_service_name}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.gateway_sku
    tier     = var.gateway_sku
    capacity = 2
  }

  firewall_policy_id = var.gateway_sku == "WAF_v2" ? local.waf_policy_id : null

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_identity.id]
  }

  gateway_ip_configuration {
    name      = "${var.backend_service_name}-appgw-ipcfg"
    subnet_id = data.azurerm_subnet.appgw.id
  }

  dynamic "frontend_port" {
    for_each = var.tls_enabled ? [] : [1]
    content {
      name = "http-port"
      port = 80
    }
  }

  dynamic "frontend_port" {
    for_each = var.tls_enabled ? [1] : []
    content {
      name = "https-port"
      port = 443
    }
  }

  frontend_ip_configuration {
    name                          = "appgw-fe-ip"
    public_ip_address_id          = local.public_ip_id
    private_ip_address            = var.create_public_lb ? null : local.fixed_private_ip
    private_ip_address_allocation = var.create_public_lb ? null : "Static"
    subnet_id                     = var.create_public_lb ? null : data.azurerm_subnet.appgw.id
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "placeholder-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  ssl_policy {
    policy_type          = "CustomV2"
    min_protocol_version = "TLSv1_2"
    cipher_suites = [
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    ]
  }

  dynamic "ssl_certificate" {
    for_each = var.tls_enabled ? [1] : []
    content {
      name                = "${var.backend_service_name}-cert"
      key_vault_secret_id = (var.create_ssl_cert && length(azurerm_key_vault_certificate.cert) > 0) ? azurerm_key_vault_certificate.cert[0].secret_id : var.certificate_secret_id
    }
  }

  dynamic "http_listener" {
    for_each = var.tls_enabled ? [] : [1]
    content {
      name                           = "http-listener"
      frontend_ip_configuration_name = "appgw-fe-ip"
      frontend_port_name             = "http-port"
      protocol                       = "Http"
    }
  }

  dynamic "http_listener" {
    for_each = var.tls_enabled ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "appgw-fe-ip"
      frontend_port_name             = "https-port"
      protocol                       = "Https"
      ssl_certificate_name           = "${var.backend_service_name}-cert"
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.tls_enabled ? [1] : []
    content {
      name                 = "http-to-https-redirect"
      redirect_type        = "Permanent"
      target_listener_name = "https-listener"
      include_path         = true
      include_query_string = true
    }
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = var.tls_enabled ? "https-listener" : "http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "placeholder-http-settings"
    priority                   = 1001
  }

  probe {
    name                                      = "appgw-health-probe"
    protocol                                  = "Http"
    path                                      = "/status"
    interval                                  = 30
    timeout                                   = 5
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200"]
    }
  }

  tags = local.rendered_tags_for["appgw"]

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      probe,
      request_routing_rule,
      redirect_configuration,
      tags,
      frontend_port,
      url_path_map
    ]
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "divyam" {
  count               = (var.create_ssl_cert && var.tls_enabled && var.azure_key_vault_name != null) ? 1 : 0
  name                = var.azure_key_vault_name
  resource_group_name = var.resource_group_name
}

locals {
  azure_key_vault_id = var.azure_key_vault_id != null ? var.azure_key_vault_id : try(data.azurerm_key_vault.divyam[0].id, null)
}

# TLS certificate in Key Vault when create_ssl_cert and tls_enabled (config from defaults.hcl divyam_load_balancer).
resource "azurerm_key_vault_certificate" "cert" {
  count        = (var.create_ssl_cert && var.tls_enabled && local.azure_key_vault_id != null) ? 1 : 0
  name         = var.cert_name
  key_vault_id = local.azure_key_vault_id

  certificate_policy {
    issuer_parameters {
      name = var.cert_issuer
    }

    key_properties {
      exportable = true
      key_type   = "RSA"
      key_size   = 2048
      reuse_key  = false
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=${local.api_dns_fqdn}"
      validity_in_months = var.cert_validity_in_months
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      subject_alternative_names {
        dns_names = compact([
          local.api_dns_fqdn,
          local.dashboard_dns_fqdn,
          local.controlplane_dns_fqdn
        ])
      }

      key_usage = ["digitalSignature", "keyEncipherment"]
    }
  }

  tags = local.rendered_tags_for["cert"]
}

resource "azurerm_key_vault_access_policy" "appgw_key_vault_access" {
  count        = local.azure_key_vault_id != null ? 1 : 0
  key_vault_id = local.azure_key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_identity.principal_id

  certificate_permissions = ["Get", "List"]
  secret_permissions      = ["Get", "List"]
}

resource "azurerm_user_assigned_identity" "agic_identity" {
  name                = "${var.backend_service_name}-agic-id"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.rendered_tags_for["agic_identity"]
}

# IP used for DNS A records: public when create_public_lb, private otherwise.
locals {
  lb_ip_for_dns = var.create_public_lb ? local.public_ip_address : azurerm_application_gateway.appgw.frontend_ip_configuration[0].private_ip_address
}

# Private DNS zone and A records for api/dashboard/control hosts.
resource "azurerm_private_dns_zone" "app" {
  count               = var.create_dns_records && local.private_dns_zone_name != "" && var.create_private_dns_zone ? 1 : 0
  name                = local.private_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = local.rendered_tags_for["appgw"]
}

data "azurerm_private_dns_zone" "app" {
  count               = var.create_dns_records && local.private_dns_zone_name != "" && !var.create_private_dns_zone ? 1 : 0
  name                = local.private_dns_zone_name
  resource_group_name = var.resource_group_name
}

locals {
  # Single source of truth for zone name regardless of create-vs-existing mode.
  effective_private_dns_zone_name = local.private_dns_zone_name == "" ? null : (var.create_private_dns_zone ? azurerm_private_dns_zone.app[0].name : data.azurerm_private_dns_zone.app[0].name)
}

resource "azurerm_private_dns_a_record" "api" {
  count               = var.create_dns_records && local.effective_private_dns_zone_name != null && trimspace(var.api_dns_record_name) != "" ? 1 : 0
  name                = trimspace(var.api_dns_record_name)
  zone_name           = local.effective_private_dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [local.lb_ip_for_dns]
  tags                = local.rendered_tags_for["appgw"]
}

resource "azurerm_private_dns_a_record" "dashboard" {
  count               = var.create_dns_records && local.effective_private_dns_zone_name != null && trimspace(var.dashboard_dns_record_name) != "" ? 1 : 0
  name                = trimspace(var.dashboard_dns_record_name)
  zone_name           = local.effective_private_dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [local.lb_ip_for_dns]
  tags                = local.rendered_tags_for["appgw"]
}

resource "azurerm_private_dns_a_record" "controlplane" {
  count               = var.create_dns_records && local.effective_private_dns_zone_name != null && trimspace(var.controlplane_dns_record_name) != "" ? 1 : 0
  name                = trimspace(var.controlplane_dns_record_name)
  zone_name           = local.effective_private_dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [local.lb_ip_for_dns]
  tags                = local.rendered_tags_for["appgw"]
}

resource "azurerm_private_dns_zone_virtual_network_link" "primary_vnet" {
  count                 = var.create_dns_records && local.effective_private_dns_zone_name != null ? 1 : 0
  name                  = "${replace(local.effective_private_dns_zone_name, ".", "-")}-${replace(var.vnet_name, ".", "-")}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = local.effective_private_dns_zone_name
  virtual_network_id    = data.azurerm_virtual_network.vnet[0].id
  # Resolution-only link. Prevent automatic VM hostname registration into this shared app zone.
  registration_enabled  = false
  tags                  = local.rendered_tags_for["appgw"]
}

resource "azurerm_private_dns_zone_virtual_network_link" "additional_calling_vnets" {
  for_each = var.create_dns_records && local.effective_private_dns_zone_name != null ? data.azurerm_virtual_network.additional_calling_vnets : {}
  name                  = "${replace(local.effective_private_dns_zone_name, ".", "-")}-${replace(each.value.name, ".", "-")}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = local.effective_private_dns_zone_name
  virtual_network_id    = each.value.id
  # Keep additional caller VNets resolution-only for predictable record ownership.
  registration_enabled  = false
  tags                  = local.rendered_tags_for["appgw"]
}
