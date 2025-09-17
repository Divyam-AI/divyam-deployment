# Public or Internal IP
resource "azurerm_public_ip" "lb_ip" {
  count = var.create_public_lb ? 1 : 0
  # TODO: generate better name prefix
  name                = "${var.backend_service_name}-public-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_private_endpoint" "lb_internal_ip" {
  count               = var.create_public_lb ? 0 : 1
  name                = "${var.backend_service_name}-private-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_ids[var.vnet_subnet_name]

  private_service_connection {
    name                           = "appgw-connection"
    private_connection_resource_id = azurerm_application_gateway.appgw.id
    is_manual_connection           = false
    subresource_names              = ["frontendIPConfigurations"]
  }
}

# Create a user-assigned identity
resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = "${var.backend_service_name}-appgw-uami"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = "${var.backend_service_name}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_identity.id]
  }

  gateway_ip_configuration {
    name      = "${var.backend_service_name}-appgw-ipcfg"
    subnet_id = var.subnet_ids[var.vnet_subnet_name]
  }

  dynamic "frontend_port" {
    for_each = var.certificate_secret_id == null ? [1] : []
    content {
      name = "http-port"
      port = 80
    }
  }

  dynamic "frontend_port" {
    for_each = var.certificate_secret_id != null ? [1] : []
    content {
      name = "https-port"
      port = 443
    }
  }

  frontend_ip_configuration {
    name                          = "appgw-fe-ip"
    public_ip_address_id          = var.create_public_lb ? azurerm_public_ip.lb_ip[0].id : null
    private_ip_address_allocation = var.create_public_lb ? null : "Dynamic"
    subnet_id                     = var.create_public_lb ? null : var.subnet_ids[var.vnet_subnet_name]
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    # AGIC creates the backends for exposed service from within the AKS cluster.
    name                  = "placeholder-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  ssl_policy {
    policy_type          = "CustomV2"
    min_protocol_version = "TLSv1_2" # Enforce TLS 1.2 or higher

    cipher_suites = [
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    ]
  }

  dynamic "ssl_certificate" {
    for_each = var.certificate_secret_id != null ? [1] : []
    content {
      name                = "${var.backend_service_name}-cert"
      key_vault_secret_id = var.certificate_secret_id
    }
  }

  dynamic "http_listener" {
    for_each = var.certificate_secret_id == null ? [1] : []
    content {
      name                           = "http-listener"
      frontend_ip_configuration_name = "appgw-fe-ip"
      frontend_port_name             = "http-port"
      protocol                       = "Http"
    }
  }

  dynamic "http_listener" {
    for_each = var.certificate_secret_id != null ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "appgw-fe-ip"
      frontend_port_name             = "https-port"
      protocol                       = "Https"
      ssl_certificate_name           = "${var.backend_service_name}-cert"
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.certificate_secret_id != null ? [1] : []
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
    http_listener_name         = var.certificate_secret_id != null ? "https-listener" : "http-listener"
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

resource "azurerm_key_vault_access_policy" "appgw_key_vault_access" {
  key_vault_id = var.azure_key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_identity.principal_id

  certificate_permissions = ["Get", "List"]
  secret_permissions      = ["Get", "List"]
}

resource "azurerm_user_assigned_identity" "agic_identity" {
  name                = "${var.backend_service_name}-agic-id"
  location            = var.location
  resource_group_name = var.resource_group_name
}
