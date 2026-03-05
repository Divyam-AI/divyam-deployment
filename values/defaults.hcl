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
  # Standard template variables are defined as part of tag_globals in root level terragrunt.hcl
  # { 
  #   environment     = "#{environment}"
  #   region          = "#{region}"
  #   resource_tag    = "#{org_name}-#{resource_name}"
  # }

# --- Resource Scope ---
# Azure: resource_group_name | GCP: project_id
  resource_scope = {
    create  = false
    name    = "${local.deployment_prefix}-rg"
    #name   =  "rg-sudhir-4084" # Azure
    #name   = "prod-benchmarking" # GCP
  }

# --- Virtual Network ---
  # Azure: VNet | GCP: Shared VPC
  vnet = {
    create          = true
    name            = "${local.deployment_prefix}-vnet"
    scope_name      = "${local.resource_scope.name}" # Azure Resource Group or GCP Project where this vnet is to be created/present
    region          = "${local.region}"
    zone            = "${local.zone}"
    address_space   = ["10.0.0.0/16"]
    subnets         = [
        { create = true, subnet_name = "${local.deployment_prefix}-subnet", subnet_ip = "10.0.0.0/21" } # (2048 IPs)
      ]
    app_gw_subnet   = local.cloud_provider == "azure" ? [
        # (32 IPs)  - Required only for Azure App Gateway. Ignore for rest
        { create = true, subnet_name = "${local.deployment_prefix}-subnet-app-gw", subnet_ip = "10.0.8.0/27" }
      ]: []
  }

# --- Blob / Object Storage ---
# Azure: Resource Group -> Storage Account -> Container | GCP: Project -> GCS bucket(s)
  # --- Terraform State Backend ---  
  tfstate = {
    create         = true
    region         = "${local.region}"
    zone           = "${local.zone}"
    scope_name     = "${local.resource_scope}"                              # Azure Resource Group or GCP Project
    storage_name   = "storage"                                              # Azure Storage Account or GCP - empty
    container_name = "${replace(local.deployment_prefix, "-", "")}tfstate"  # Azure Container or GCP Bucket
  }

  # --- Divyam Data ---
  divyam_object_storage = {
    create = true
    scope_name       = "${local.resource_scope}"                        # Azure Resource Group or GCP Project
    storage_name     = "storage"                                        # Azure Storage Account or GCP - empty
    container_name   = "${replace(local.deployment_prefix, "-", "")}"   # Azure Container or GCP Bucket
  }

  # --- Kubernetes Cluster ---
  # Azure: AKS | GCP: GKE
  k8s = {
    create = true
    name   = "${local.deployment_prefix}-cluster"
  }

  # -- Static IP for Load Balancer ---
  divyam_static_ip_load_balancer = {
    create = true
    ip     = ""
  }

  # -- Secrets ---
  divyam_secrets = {
    create = true
    scope_name = "${local.resource_scope.name}"       # Azure Resource Group or GCP Project
    store_name = "${local.deployment_prefix}-vault"   # Azure Key Vault or GCP - Ignored    
  }
}