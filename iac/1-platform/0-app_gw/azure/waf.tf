# WAF policy: create in-module or fetch by name (from defaults.hcl divyam_load_balancer).
# Attached to Application Gateway via firewall_policy_id.

locals {
  waf_policy_name = coalesce(var.waf_policy_name, "${var.backend_service_name}-waf")
}

resource "azurerm_web_application_firewall_policy" "waf" {
  count                = var.waf_enabled && var.create_waf && var.gateway_sku == "WAF_v2" ? 1 : 0
  name                 = local.waf_policy_name
  resource_group_name  = var.resource_group_name
  location             = var.location
  tags                 = local.rendered_tags_for["appgw"]

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  dynamic "custom_rules" {
    for_each = length(var.waf_allow_ip_ranges) > 0 ? [1] : []
    content {
      name     = "allowlist"
      priority = 100
      rule_type = "MatchRule"
      action   = "Allow"
      match_conditions {
        match_variables {
          variable_name = "RemoteAddr"
        }
        operator         = "IPMatch"
        match_values     = var.waf_allow_ip_ranges
        negation_condition = false
      }
    }
  }

  dynamic "custom_rules" {
    for_each = length(var.waf_deny_ip_ranges) > 0 ? [1] : []
    content {
      name     = "denylist"
      priority = 200
      rule_type = "MatchRule"
      action   = "Block"
      match_conditions {
        match_variables {
          variable_name = "RemoteAddr"
        }
        operator         = "IPMatch"
        match_values     = var.waf_deny_ip_ranges
        negation_condition = false
      }
    }
  }

  # When allow list is set, block all other IPs (default deny).
  dynamic "custom_rules" {
    for_each = length(var.waf_allow_ip_ranges) > 0 ? [1] : []
    content {
      name     = "default-deny"
      priority = 300
      rule_type = "MatchRule"
      action   = "Block"
      match_conditions {
        match_variables {
          variable_name = "RemoteAddr"
        }
        operator         = "IPMatch"
        match_values     = ["0.0.0.0/0"]
        negation_condition = false
      }
    }
  }
}

data "azurerm_web_application_firewall_policy" "waf_existing" {
  count                = var.waf_enabled && !var.create_waf && var.gateway_sku == "WAF_v2" ? 1 : 0
  name                 = local.waf_policy_name
  resource_group_name  = var.resource_group_name
}

locals {
  waf_policy_id = var.waf_enabled && var.gateway_sku == "WAF_v2" ? (var.create_waf ? azurerm_web_application_firewall_policy.waf[0].id : data.azurerm_web_application_firewall_policy.waf_existing[0].id) : null
}
