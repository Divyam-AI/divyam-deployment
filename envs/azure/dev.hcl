#----------------------------------------------
# Azure Dev Environment Configuration
# Consolidated from defaults.hcl + dev overrides
#----------------------------------------------
locals {
  # Environment settings
  env_name        = "dev"
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "")
  tenant_id       = get_env("ARM_TENANT_ID", "")
  location        = get_env("LOCATION", "centralindia")
  region          = local.location

  # Resource naming
  org                  = ""
  resource_name_prefix = get_env("AZURE_RESOURCE_PREFIX", "divyam-dev")
  resource_group_name  = get_env("AZURE_RESOURCE_GROUP", "${local.resource_name_prefix}-rg")

  # Common tags applied to all resources
  common_tags = {
    Environment = local.env_name
    ManagedBy   = "terraform"
  }

  #----------------------------------------------
  # Component configurations
  #----------------------------------------------

  # Resource Group (bootstrap)
  resource_group = {
    enabled = false
  }

  # Terraform State Storage
  tfstate_azure_blob_storage = {
    enabled                  = true
    create                   = true
    storage_account_name     = "${replace(local.resource_name_prefix, "-", "")}tfstate"
    storage_container_name   = "tfstate"
    storage_account_ip_rules = []
  }

  # Virtual Network
  vnet = {
    enabled           = true
    use_existing_vnet = false
    network_name      = "${local.resource_name_prefix}-vnet"
    address_space     = ["10.0.0.0/16"]
    subnets = [
      {
        subnet_name  = "internal"
        use_existing = false
        subnet_ip    = "10.0.1.0/24"
      },
      {
        subnet_name  = "app-gw"
        use_existing = false
        subnet_ip    = "10.0.2.0/24"
      }
    ]
  }

  # AKS Kubernetes Cluster
  aks = {
    enabled           = true
    agic_helm_version = "1.8.1"
    cluster = {
      name                    = "${local.resource_name_prefix}-cluster"
      dns_prefix              = "${local.resource_name_prefix}-cluster"
      kubernetes_version      = "1.33.1"
      private_cluster_enabled = false
      vnet_subnet_name        = "internal"

      # Network configuration
      service_cidr   = "10.24.0.0/16"
      dns_service_ip = "10.24.0.10"
      cluster_cidr   = "172.17.0.1/16"

      # System/default node pool
      default_node_pool = {
        vm_size      = "Standard_DS4_v2"
        count        = 6
        auto_scaling = false
      }

      # Additional node pools
      additional_node_pools = {
        gpupool = {
          vm_size      = "Standard_NV6ads_A10_v5"
          count        = 2
          auto_scaling = false
          node_taints  = ["sku=gpu:NoSchedule"]
          node_labels = {
            gpu = tostring(true)
          }
        }
      }
    }
  }

  # Azure Blob Storage
  azure_blob_storage = {
    enabled = true
    divyam_router_logs_storage_container_names = [
      "divyam-router-raw-logs"
    ]
    storage_account_ip_rules = []
  }

  # Application Gateway
  app_gw = {
    enabled          = true
    create_public_lb = false
    vnet_subnet_name = "app-gw"
  }

  # NAT Gateway
  nat = {
    enabled = true
    create  = true
  }

  # Azure Key Vault (secrets)
  azure_key_vault = {
    enabled = true
  }

  # Key Vault Secrets
  azure_key_vault_secrets = {
    enabled                     = true
    divyam_db_user_name         = "divyam"
    divyam_clickhouse_user_name = "default"
  }

  # AKS Namespaces
  aks_namespaces = {
    enabled = true
  }

  # IAM Bindings
  iam_bindings = {
    enabled = true
  }

  # DNS
  dns = {
    enabled = true
  }

  # TLS Certificates
  tls_certs = {
    enabled = true
    create  = false
  }

  # Bastion Host
  bastion_host = {
    enabled          = false
    vnet_subnet_name = "internal"
  }

  # Helm Charts
  helm_charts = {
    enabled                        = true
    divyam_helm_registry_url       = "oci://asia-south1-docker.pkg.dev/prod-benchmarking/divyam-helm-dev-as1"
    divyam_docker_registry_url     = "asia-south1-docker.pkg.dev/prod-benchmarking/divyam-router-docker-as1"
    helm_release_replace_all       = true
    helm_release_recreate_pods_all = true
    helm_release_force_update_all  = true
    exclude_charts                 = ["divyam_bill_tracker"]
  }

  # Alerts/Monitoring
  alerts = {
    enabled = true
  }
}
