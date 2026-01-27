locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

resource "azurerm_key_vault_certificate" "cert" {
  count        = var.create ? 1 : 0
  name         = var.cert_name
  key_vault_id = var.azure_key_vault_id

  certificate_policy {
    issuer_parameters {
      name = var.issuer
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
      subject            = "CN=${var.router_dns_zone}"
      validity_in_months = 12
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      subject_alternative_names {
        dns_names = [
          var.router_dns_zone,
          var.dashboard_dns_zone
        ]
      }

      key_usage = ["digitalSignature", "keyEncipherment"]
    }
  }

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.cert_name
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}
