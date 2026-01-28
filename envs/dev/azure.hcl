#----------------------------------------------
# Dev environment Azure-specific settings
#----------------------------------------------
locals {
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "")
  tenant_id       = get_env("ARM_TENANT_ID", "")
  location        = get_env("LOCATION", "centralindia")

  vnet = {
    use_existing_vnet = true
    subnets = [
      {
        subnet_name  = "internal"
        use_existing = true
      },
      {
        subnet_name  = "app-gw"
        use_existing = true
      }
    ]
  }

  aks = {
    cluster = {
      vnet_subnet_name = "internal"

      # System/default node pool
      default_node_pool = {
        vm_size      = "Standard_DS4_v2"
        count        = 6
        auto_scaling = false
      }

      # Additional node pools
      additional_node_pools = {
        # GPU node pool
        gpupool = {
          vm_size      = "Standard_NV6ads_A10_v5"
          count        = 2
          auto_scaling = false

          node_taints = ["sku=gpu:NoSchedule"]
          node_labels = {
            gpu = tostring(true)
          }
        }
      }
    }
  }

  bastion_host = {
    vnet_subnet_name = "internal"
  }

  app_gw = {
    vnet_subnet_name = "app-gw"
  }

  tls_certs = {
    create = false
  }
}
