locals {
  resource_group_name = "az-anurag-dev"
  #org = "acme"

  # Common tags applied to all resources.
  common_tags = {
    Environment = "@{environment}"
    Name : "@{resource_name}"
  }

  tfstate_azure_blob_storage = {
    create = true
    storage_account_name = "divyamanuragdevtfstate"
    storage_account_ip_rules = [
      "122.171.22.0/24",
          "171.76.83.180",
          "180.151.117.0/20"
    ]
  }

  vnet = {
    network_name = "divyam-dev-vnet"
    use_existing_vnet = false

    subnets = [
      {
        subnet_name  = "internal"
        use_existing = false
        subnet_ip   = "10.0.1.0/24"
      },
      {
        subnet_name  = "app-gw"
        use_existing = false
        subnet_ip   = "10.0.2.0/24"
      }
    ]
  }

  aks = {
    cluster = {
      vnet_subnet_name = "internal"
      private_cluster_enabled = false

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
          #auto_scaling = true
          #min_count    = 1
          #max_count    = 1


          node_taints = ["sku=gpu:NoSchedule"]
          node_labels = {
            # Important to use tostring otherwise k8s get the value as bool,
            # when only strings are allowed.
            gpu = tostring(true)
            # Add special label for azure gpu type maybe.
          }
        }
      }

      # Networking
      api_server_authorized_ip_ranges = [
           "122.171.22.0/24",                                                                                                                                                                                                                                                                                 "171.76.83.180/32"
      ]
    }
  }

  bastion_host = {
    enabled          = false
    vnet_subnet_name = "internal"
  }

  app_gw = {
    vnet_subnet_name = "app-gw"
  }

  alerts = {
    notification_zenduty_webhook_url = "https://events.zenduty.com/integration/vv0kf/microsoftazure/a3ccb7a9-f502-406f-8ed0-b3c3febe8e9e/"
  }

  resource_group = {
    enabled = false
  }

  azure_key_vault_secrets = {
    enabled = false
  }

  iam_bindings = {
    enabled = false
  }

  helm_charts = {
    enabled = false
  }

}
