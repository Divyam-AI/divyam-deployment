#----------------------------------------------
# Preprod environment Azure-specific settings
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
      kubernetes_version = "1.33.1"
    }
  }

  bastion_host = {
    enabled = false
  }

  app_gw = {
    enabled = true
  }

  tls_certs = {
    create = false
  }

  azure_key_vault = {
    enabled = true
  }
}
