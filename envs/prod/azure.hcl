#----------------------------------------------
# Prod environment Azure-specific settings
#----------------------------------------------
locals {
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "")
  tenant_id       = get_env("ARM_TENANT_ID", "")
  location        = get_env("LOCATION", "centralindia")

  vnet = {
    enabled           = true
    use_existing_vnet = false
    address_space     = ["10.0.0.0/16"]
  }

  aks = {
    enabled = true
    cluster = {
      kubernetes_version      = "1.33.1"
      private_cluster_enabled = true
    }
  }

  bastion_host = {
    enabled = true
  }

  app_gw = {
    enabled          = true
    create_public_lb = true
  }

  tls_certs = {
    enabled = true
    create  = true
  }

  azure_key_vault = {
    enabled = true
  }

  azure_key_vault_secrets = {
    enabled = true
  }

  dns = {
    enabled = true
  }
}
