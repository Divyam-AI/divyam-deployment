#----------------------------------------------
# Default values for all Divyam components
#
# This file can only rely on any environment
# variables. Will be evaluated first with no access to environment specific
# overrides
#----------------------------------------------
locals {
  env_name = get_env("ENV", "dev")
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "")
  tenant_id = get_env("ARM_TENANT_ID", "")
  location = get_env("LOCATION", "")

  # Used to disambiguate resource names.
  org = ""

  # Common tags applied to all resources.
  common_tags = {
    Environment = "@{environment}"
    # Can be a template. Available variables are resource_name, location,
    # resource_group and environment. For example.

    #Name: "@{resource_name}"
  }

  # Component configuration
  resource_group = {
    enabled = false
  }

  tfstate_azure_blob_storage = {
    enabled = true
    create = true
    # Allow access only from the associated subnets.
    storage_account_ip_rules = []
  }

  azure_blob_storage = {
    enabled = true
    divyam_router_logs_storage_container_names = [
      "divyam-router-raw-logs"
    ]
    # Allow access only from the associated subnets.
    storage_account_ip_rules = []
  }

  vnet = {
    enabled           = true
    use_existing_vnet = false
    address_space = ["10.0.0.0/16"]
  }

  aks = {
    enabled = true
    agic_helm_version = "1.8.1"
    cluster = {
      kubernetes_version = "1.33.1"
      private_cluster_enabled = true

      # Preset default CIDRs.
      service_cidr   = "10.24.0.0/16"
      dns_service_ip = "10.24.0.10"
      cluster_cidr   = "172.17.0.1/16"
    }
  }

  bastion_host = {
    enabled = false
  }

  helm_charts = {
    enabled                    = true
    divyam_helm_registry_url   = "oci://asia-south1-docker.pkg.dev/prod-benchmarking/divyam-helm-dev-as1"
    divyam_docker_registry_url = "asia-south1-docker.pkg.dev/prod-benchmarking/divyam-router-docker-as1"

    helm_release_replace_all       = true
    helm_release_recreate_pods_all = true
    helm_release_force_update_all = true

    # List of helm charts to exclude.
    exclude_charts = ["divyam_bill_tracker"]
  }

  app_gw = {
    enabled          = true
    create_public_lb = false
  }

  nat = {
    enabled = true
    create  = true
  }

  azure_key_vault = {
    enabled = true
  }

  azure_key_vault_secrets = {
    enabled                     = true
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
  }

  tls_certs = {
    enabled = true
    create  = false
  }

  alerts = {
    enabled      = true
    exclude_list = []
  }
}
