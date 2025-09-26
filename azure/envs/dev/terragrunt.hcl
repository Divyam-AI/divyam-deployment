locals {
  env_name = get_env("ENV", "dev")
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "")
  tenant_id = get_env("ARM_TENANT_ID", "")
  location = get_env("LOCATION", "")

  # TODO: Add org if present to all names
  # Used to disambiguate resource names.
  # Leave empty to not not use the org name.
  org            = ""
  resource_group_name = "Divyam-Training"
  aks_cluster_name    = "divyam-aks-${local.env_name}-cluster"
  resource_group = {
    enabled = false
  }

  # Common tags applied to all resources.
  common_tags = {
    Environment = "@{environment}"
    # Can be a template. Available variables are resource_name, location,
    # resource_group and environment. For example.

    #Name: "@{resource_name}"
  }

  tfstate_azure_blob_storage = {
    enabled = true
    create = false
    # In production this should only allow access from the bastion/vnet
    storage_account_ip_rules = ["0.0.0.0/0"]
  }

  azure_blob_storage = {
    enabled                                 = true
    divyam_router_logs_storage_account_name = "divyam${local.env_name}storage"
    divyam_router_logs_storage_container_names = [
      "divyam-router-raw-logs"
    ]
    # In production this should only allow access from the bastion/vnet
    storage_account_ip_rules = ["0.0.0.0/0"]
  }

  vnet = {
    enabled      = true
    network_name = "divyam-${local.env_name}-vnet"
    use_existing_vnet = true
    #address_space = ["10.0.0.0/16"]

    subnets = [
      {
        subnet_name  = "internal"
        use_existing = true
        #subnet_ip   = "10.0.1.0/24"
      },
      {
        subnet_name  = "app-gw"
        use_existing = true
        #subnet_ip   = "10.0.2.0/24"
      }
    ]
  }

  aks = {
    enabled = true
    clusters = {
      "${local.aks_cluster_name}" = {
        dns_prefix         = "aks${local.env_name}"
        kubernetes_version = "1.33.1"
        vnet_subnet_name   = "internal"
        private_cluster_enabled = true

        # System/default node pool
        default_node_pool = {
          vm_size      = "Standard_DS4_v2"
          count        = 5
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
            tags = {
              type = "gpu"
            }
          }
        }

        # Networking
        api_server_authorized_ip_ranges = [
          # Allowed IP list for public AKS clusters
          # TODO: comment back
          "171.76.82.164/32",
          "180.151.117.0/24",
        ]

        service_cidr   = "10.24.0.0/16"
        dns_service_ip = "10.24.0.10"
        cluster_cidr   = "172.17.0.1/16"
      }
    }
  }

  bastion_host = {
    enabled          = false
    bastion_name     = "divyam-${local.env_name}-bastion"
    vnet_subnet_name = "internal"
  }

  helm_charts = {
    enabled                    = true
    aks_cluster_name           = local.aks_cluster_name
    artifacts_path = abspath("${get_parent_terragrunt_dir()}/../${local.env_name}/artifacts.yaml")
    values_dir_path = abspath("${get_parent_terragrunt_dir()}/../../helm_values")
    divyam_helm_registry_url   = "oci://asia-south1-docker.pkg.dev/prod-benchmarking/divyam-helm-dev-as1"
    divyam_docker_registry_url = "asia-south1-docker.pkg.dev/prod-benchmarking/divyam-router-docker-as1"

    helm_release_replace_all       = true
    helm_release_recreate_pods_all = true
    helm_release_force_update_all = true

    # List of helm charts to exclude.
    exclude_charts = ["divyam_bill_tracker"]
  }

  app_gw = {
    enabled              = true
    backend_service_name = "divyam-${local.env_name}-app-gw"
    create_public_lb     = false
    vnet_subnet_name     = "app-gw"
  }

  nat = {
    enabled          = true
    create = false
    vnet_subnet_name = "internal"
    resource_name_prefix = "divyam"
  }

  azure_key_vault = {
    enabled        = true
    key_vault_name = "divyam-${local.env_name}-vault"
  }

  azure_key_vault_secrets = {
    enabled = true

    divyam_db_user_name         = "divyam"
    divyam_clickhouse_user_name = "default"
  }

  aks_namespaces = {
    enabled = true
  }

  iam_bindings = {
    enabled = true
  }

  dns = {
    enabled = true
    router_dns_zone = (local.org != "" ?
      "api.${local.env_name}.${local.org}.divyam.local" :
      "${local.env_name}.divyam.local")

    dashboard_dns_zone = (local.org != "" ?
      "dashboard.${local.env_name}.${local.org}.divyam.local" :
      "${local.env_name}.dashboard.divyam.local")
  }

  tls_certs = {
    enabled   = true
    create    = false
    cert_name = (local.org != "" ?
      "divyam-${local.env_name}-${local.org}-cert" :
      "divyam-${local.env_name}-cert")
  }
}
