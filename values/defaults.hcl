#----------------------------------------------
# Cloud-agnostic deployment configuration.
# These values feed into both Azure and GCP. Cloud-specific overrides live in
# values/azure/ and values/gcp/ respectively.
#
# When create = false, use existing resources; provide the names below for lookup.
#----------------------------------------------

locals {
  # Can replace these with actual values
  cloud_provider    = get_env("CLOUD_PROVIDER") 
  env_name          = get_env("ENV")
  org_name          = get_env("ORG_NAME")
  region            = get_env("REGION")
  zone              = get_env("ZONE")

  deployment_prefix = (
    length(local.org_name) > 0 ?
      "divyam-${local.org_name}-${local.env_name}" :
      "divyam-${local.env_name}"
  )

  # Can set key -> value for tags to be applied for cloud entities
  common_tags       = { sudhir_environment     = "test-#{environment}" } 
  # Can also use templates as value and will automatically replaced
  # Standard template variables are defined as part of tag_globals in root.hcl
  # { 
  #   environment     = "#{environment}"
  #   region          = "#{region}"
  #   resource_tag    = "#{org_name}-#{resource_name}"
  # }

#################### Foundation ##########################
# --- Resource Scope ---
# Azure: resource_group_name | GCP: project_id
  resource_scope = {
    create  = false
    #name    = "${local.deployment_prefix}-rg"
    name    = local.cloud_provider == "azure" ? "rg-sudhir-4084" : "sudhir-workspace" # Azure | GCP
  }

# --- Virtual Network ---
  # Azure: VNet | GCP: Shared VPC
  # When create = true (e.g. GCP): create network and subnets. When false: look up existing by name.
  vnet = {
    create          = false
    # TODO: Remove these temp values
    #name            = "${local.deployment_prefix}-vnet"
    name            = local.cloud_provider == "azure" ? "rg-sudhir-4084-vnet" : "default" # Azure | GCP
    scope_name      = "${local.resource_scope.name}" # Azure Resource Group or GCP Project where this vnet is to be created/present
    region          = "${local.region}"
    zone            = "${local.zone}"
    address_space   = ["10.0.0.0/16"]
    # TODO: Remove these temp values
    subnet          = { create = false, subnet_ip = "10.0.0.0/21", name = local.cloud_provider == "azure" ? "rg-sudhir-4084-subnet" : "default"  } # "${local.deployment_prefix}-subnet" (2048 IPs)
    app_gw_subnet   = { create = false, subnet_ip = "10.0.8.0/27", name = local.cloud_provider == "azure" ? "rg-sudhir-4084-app-gw-subnet" : "default-app-gw-subnet" } # "${local.deployment_prefix}-subnet-app-gw" (32 IPs)  - Required for Azure App Gateway or GCP Proxy
  }

# --- Blob / Object Storage ---
# Azure: Resource Group -> Storage Account -> Container | GCP: Project -> GCS bucket(s)
  # --- Terraform State Backend ---
  # bucket_name: cloud-agnostic logical name for state store (Azure: container + storage account; GCP: bucket).
  # Override in values/azure/defaults.hcl or values/gcp/defaults.hcl if needed (e.g. storage_account_name, container_name for Azure).
  tfstate = {
    create         = true
    region         = "${local.region}"
    zone           = "${local.zone}"
    scope_name     = "${local.resource_scope}"                              # Azure Resource Group or GCP Project
    storage_name   = "storage"                                              # Azure Storage Account or GCP - empty
    bucket_name    = "${replace(local.deployment_prefix, "-", "")}tfstate" # Azure container + storage account name; GCP bucket name
  }

#################### Platform ##########################
  # --- Divyam Data ---
  divyam_object_storages = [{
    create               = true
    type                 = "router-requests-logs"                                  # Identifies this storage for router-requests-logs
    scope_name           = "${local.resource_scope}"                               # Azure Resource Group or GCP Project
    storage_account_name = "${replace(local.deployment_prefix, "-", "")}storage"   # Full Azure storage account name (no dashes). Not for GCP; used for grouping
    container_name       = "${replace(local.deployment_prefix, "-", "")}container" # Azure Container or GCP Bucket
  }]

  # -- Secrets ---
  divyam_secrets = {
    create_vault   = true   # Azure only: if false, use store_name to look up existing Key Vault
    create_secrets = true   # if false, do not create or update secrets in the vault
    scope_name     = "${local.resource_scope.name}"       # Azure Resource Group or GCP Project
    # TODO: Change the defaults
    # store_name     = "${local.deployment_prefix}-vault"   # Azure Key Vault name (create or lookup)
    store_name     = local.cloud_provider == "azure" ? "divyam-dev-vault-4048" : "${local.deployment_prefix}-vault"   # Azure Key Vault name (create or lookup). Not required for GCP
    
  }

  # -- Load Balancer (static IP, DNS, TLS) ---
  divyam_load_balancer = {
    create_ip = true
    # Private IP (internal LB only): address and optional resource name.
    ip               = "10.0.8.10"  # Reserved private IP in VNET app_gw_subnet (ignored when public = true)
    private_ip_name  = "${local.deployment_prefix}-private-ip"  # Name for the private IP resource (e.g. GCP internal address)

    public = false
    create_public_ip = true  # When true and public = true, create new public IP; when false, use existing by public_ip_name    
    public_ip_name  = "${local.deployment_prefix}-ip"  # Name for new public IP, or name of existing if create_public_ip = false

    service_name         = "${local.deployment_prefix}-service"
    backend_service_name = "${local.deployment_prefix}-service-backend"

    tls_enabled     = true
    create_ssl_cert = true  # Used only if tls_enabled is true. When false, use external cert (certificate_secret_id).
    ssl_cert_name   = "${local.deployment_prefix}-lb-ssl-cert"

    # DNS names for TLS SANs and for DNS A records (IP mapping: these names resolve to LB IP — public when public=true, private when false).
    create_dns_records = true  # When true, create Private DNS A records mapping router_dns/dashboard_dns to LB IP.
    router_dns = (local.org_name != "" ?
      "api.${local.env_name}.${local.org_name}.divyam.local" :
      "api.${local.env_name}.divyam.local")
    dashboard_dns = (local.org_name != "" ?
      "dashboard.${local.env_name}.${local.org_name}.divyam.local" :
      "${local.env_name}.dashboard.divyam.local")

    waf_enabled = true
    create_waf  = true   # When true, create WAF/Cloud Armor policy in-module; when false and waf_enabled, fetch existing by waf_policy_name and attach
    waf_policy_name = "${local.deployment_prefix}-waf"  # Name for created policy or name of existing to fetch when create_waf = false

    # WAF deny/allow lists (applied when create_waf = true). Empty = no rule.
    waf_deny_ip_ranges  = []  # IP/CIDR to block (e.g. ["203.0.113.0/24"])
    waf_allow_ip_ranges = []  # If non-empty: only these IP/CIDR allowed (allowlist); still apply deny list first
  }

  # --- Kubernetes Cluster ---
  # Azure: AKS | GCP: GKE
  k8s = {
    create = true
    name   = "${local.deployment_prefix}-cluster"
  }

  iam_bindings = {
    create = false
  }

#################### Application ##########################

}