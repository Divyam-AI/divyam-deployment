#----------------------------------------------
# Cloud-agnostic deployment configuration.
# These values feed into both Azure and GCP. Cloud-specific overrides live in
# values/azure/ and values/gcp/ respectively.
#
# When create = false, use existing resources; provide the names below for lookup.
#----------------------------------------------

locals {
  env_name          = get_env("ENV")
  org_name          = get_env("ORG_NAME")

  # Same nomenclature for all clouds; set via env REGION, ZONE.
  region = get_env("REGION")
  zone   = get_env("ZONE")

  deployment_prefix = (
    length(local.org_name) > 0 ?
      "divyam-${local.org_name}-${local.env_name}" :
      "divyam-${local.env_name}"
  )

  common_tags = { sudhir_environment     = "test-#{environment}" } # Can set key -> value for tags to be applied for entities
  # Can also use templates as value and will automatically replaced
  # Standard template variables are defined as part of tag_globals in root level terragrunt.hcl
  # { 
  #   environment     = "#{environment}"
  #   region          = "#{region}"
  #   resource_name   = "#{resource_name}"
  # }

# --- Resource Scope ---
  # Azure: resource_group_name | GCP: project_id
  resource_scope = {
    create = true
    name   =  "rg-sudhir-4084" #"${local.deployment_prefix}-rg"
  }

# --- Blob / Object Storage ---
# Azure: Resource Group -> Storage Account -> Container | GCP: Project -> GCS bucket(s)
  # --- Terraform State Backend ---  
  tfstate = {
    create         = true

    scope_name       = "${local.resource_scope}"                            # Azure Resource Group or GCP Project
    storage_name     = "storage"                                            # Azure Storage Account or GCP - empty
    container_name = "${replace(local.deployment_prefix, "-", "")}tfstate"  # Azure Container or GCP Bucket
  }

  # --- Divyam Data ---
  divyam_object_storage = {
    create = true

    scope_name       = "${local.resource_scope}"                      # Azure Resource Group or GCP Project
    storage_name     = "storage"                                      # Azure Storage Account or GCP - empty
    container_name = "${replace(local.deployment_prefix, "-", "")}"   # Azure Container or GCP Bucket
  }

# --- Virtual Network ---
  # Azure: VNet | GCP: Shared VPC
  vnet = {
    create = true
    name   = "${local.deployment_prefix}-vnet"
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