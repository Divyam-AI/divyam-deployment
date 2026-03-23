#----------------------------------------------
# Root Terragrunt config (single file). Reads values/defaults.hcl.
# Cloud-specific provider and backend are inlined below from CLOUD_PROVIDER (env: default azure).
#
# When run from repo root: runs resource-scope module for current CLOUD_PROVIDER.
# When included by children: provides shared locals, provider, remote_state, inputs.
# To run all foundation: terragrunt run-all plan --terragrunt-working-dir 0-foundation
#----------------------------------------------
locals {
  repo_root      = get_repo_root()
  # Values file path (relative to repo root). Override with VALUES_FILE env or 3rd script arg.
  values_file = get_env("VALUES_FILE") # VALUES_FILE to be used : values/defaults.hcl
  default_locals = read_terragrunt_config("${local.repo_root}/${local.values_file}").locals
  cloud_provider = local.default_locals.cloud_provider
  at_repo_root   = get_terragrunt_dir() == local.repo_root

  # Set TG_USE_LOCAL_BACKEND=1 (or true) to use local state for all modules — no remote backend, no state download. Useful for testing.
  use_local_backend = get_env("TG_USE_LOCAL_BACKEND", "0") != "0"
  # When tfstate.local_state is true, state is stored locally only (no cloud bucket/container).
  use_local_state_config = try(local.default_locals.tfstate.local_state, false)

  # Azure: ARM_SUBSCRIPTION_ID, ARM_TENANT_ID only read when cloud_provider is azure (inside branch below). GCP: uses ADC.
  cloud_locals = local.cloud_provider == "gcp" ? {
    cloud_provider  = "gcp"
    provider_block = <<-EOT
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  # Use Application Default Credentials (gcloud auth application-default login)
  # or set GOOGLE_APPLICATION_CREDENTIALS.
}
EOT
  } : {
    cloud_provider  = "azure"
    provider_block = <<-EOT
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.57.0"  # 4.57+ for node_provisioning_profile (Node Auto-Provisioning / NAP)
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "${get_env("ARM_SUBSCRIPTION_ID")}"
  tenant_id       = "${get_env("ARM_TENANT_ID")}"
}
EOT
  }

  merged = merge(local.default_locals, local.cloud_locals)

  # Local state filename segregated by cloud_provider, deployment_prefix, and values file (for TG_USE_LOCAL_BACKEND or at_repo_root).
  # Including values file ensures values/defaults.hcl and divyam-pre-prod-defaults.hcl (etc.) use separate state files.
  _values_parts   = split("/", local.values_file)
  _values_basename = replace(element(local._values_parts, length(local._values_parts) - 1), ".hcl", "")
  local_state_file = "terraform-${local.merged.cloud_provider}-${local.merged.deployment_prefix}-${local._values_basename}.tfstate"

  # Outputs for Helm (outputs.yaml): control which Terraform outputs are written by scripts/write-outputs-yaml.sh.
  # exclude_outputs: sensitive data (kubeconfig, connection strings, secrets, certs) — never written to outputs.yaml.
  outputs_for_helm = {
    include_modules = []
    exclude_modules = []
    include_outputs = []
    exclude_outputs = [
      "aks_kube_config",
      "aks_kube_config_raw",
      "aks_oidc_issuer_url",
      "cluster_ca_certificates",
      "uai_client_ids",
      "uai_ids",
      "secrets",
      "storage_account_connection_strings",
      "router_requests_logs_storage_account_connection_string",
      "backend_config",
      "certificate_secret_id",
    ]
  }

  # Provider block comes from values/<cloud>/defaults.hcl so only the active cloud's
  # config is loaded (no Azure subscription_id/tenant_id when CLOUD_PROVIDER=gcp).
  effective_provider_content = try(local.merged.provider_block, "")

  # When at repo root: flatten merged so resource_scope fields (create, name) are at top level and pass as-is.
  flattened = merge(local.merged, local.merged.resource_scope)

  # Inputs for 2-terraform_state_blob_storage when running from repo root (same mapping as child terragrunt.hcl).
  # Split by cloud in a map so HCL does not require identical object shapes in a ternary.
  _tfstate_repo_root_shared = {
    common_tags = try(local.merged.common_tags, {})
    tag_globals = {
      environment    = local.merged.env_name
      resource_group = local.merged.resource_scope.name
      region         = local.merged.region
      org            = local.merged.org_name
    }
    tag_context = {
      resource_name = local.merged.tfstate.bucket_name
    }
    create      = local.merged.tfstate.create && !try(local.merged.tfstate.local_state, false)
    local_state = try(local.merged.tfstate.local_state, false)
  }
  _tfstate_repo_root_cloud = {
    gcp = {
      project_id   = local.merged.resource_scope.name
      location     = local.merged.region
      environment  = local.merged.env_name
      bucket_name  = local.merged.tfstate.bucket_name
    }
    azure = {
      resource_group_name      = local.merged.resource_scope.name
      location                 = local.merged.region
      environment              = local.merged.env_name
      storage_account_name     = local.merged.tfstate.bucket_name
      storage_container_name   = local.merged.tfstate.bucket_name
      vnet_name                = try(local.merged.vnet.name, "")
      vnet_resource_group_name = try(local.merged.vnet.scope_name, "")
      subnet_ids               = {}
    }
  }
  tfstate_repo_root_inputs = merge(local._tfstate_repo_root_shared, local._tfstate_repo_root_cloud[local.cloud_provider])
}

# Default: run resource-scope from repo root. Children override with their own source.
# init -reconfigure: accept backend config changes (e.g. state path by cloud_provider/deployment_prefix) without migration prompt.
terraform {
#  source = local.at_repo_root ? "0-foundation/0-resource_scope/${local.cloud_provider}" : "."
#   source = local.at_repo_root ? "0-foundation/1-vnet/${local.cloud_provider}" : "."
    source = local.at_repo_root ? "0-foundation/2-terraform_state_blob_storage/${local.cloud_provider}" : "."

  extra_arguments "init_reconfigure" {
    commands = ["init"]
    arguments = ["-reconfigure"]
  }
}

# Remote state: config from values/defaults.hcl tfstate + resource_scope; backend type by CLOUD_PROVIDER.
# Applies to all modules that include this root (e.g. 1-platform/0-*, 0-foundation/*, 2-app/*).
# path_relative_to_include() gives each module its own state key/prefix. Use TG_USE_LOCAL_BACKEND=1 or tfstate.local_state = true for local state.
remote_state {
  backend = (local.use_local_backend || local.use_local_state_config || local.at_repo_root) ? "local" : (local.cloud_provider == "gcp" ? "gcs" : "azurerm")
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = (local.use_local_backend || local.use_local_state_config || local.at_repo_root) ? {
    path = local.local_state_file
  } : (local.cloud_provider == "gcp" ? merge(
    { bucket = local.merged.tfstate.bucket_name },
    { prefix = "${local.merged.cloud_provider}/${local.merged.deployment_prefix}/${local._values_basename}/${local.merged.region}/${path_relative_to_include()}" }
  ) : merge(
    {
      resource_group_name  = local.merged.resource_scope.name
      storage_account_name = local.merged.tfstate.bucket_name
      container_name       = local.merged.tfstate.bucket_name
    },
    { key = "${local.merged.cloud_provider}/${local.merged.deployment_prefix}/${local._values_basename}/${local.merged.region}/${path_relative_to_include()}/terraform.tfstate" }
  ))
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = local.effective_provider_content
}

generate "tagging" {
  path      = "zz_autogenerated_tags.tf"
  if_exists = "overwrite"

  contents = <<EOF
    variable "common_tags" {
      type = map(string)
    }

    variable "tag_globals" {
      type = map(string)
    }

    variable "tag_context" {
      type    = map(string)
      default = {}
    }

    locals {

      tag_context = merge(
        var.tag_globals,
        var.tag_context
      )

      rendered_tags = {
        for k, v in var.common_tags :
        k => replace(
          v,
          "/#\\{([^}]+)\\}/",
          lookup(local.tag_context, regex("#\\{([^}]+)\\}", v)[0], "")
        )
      }
    }    
    EOF
}

# When at repo root we run 2-terraform_state_blob_storage; map values/* to module inputs (same as
# 0-foundation/2-terraform_state_blob_storage/<cloud>/terragrunt.hcl). Otherwise pass merged config.
# jsonencode/jsondecode avoids HCL "inconsistent conditional result types" (tfstate-only map vs full merged).
inputs = jsondecode(local.at_repo_root ? jsonencode(local.tfstate_repo_root_inputs) : jsonencode(merge(
  local.merged,
  {
    tag_globals = {
# Add anything else that need to be used in the template for common_tags defined in values/defaults.hcl
      environment    = local.merged.env_name
      resource_group = local.merged.resource_scope.name
      region         = local.merged.region
      org            = local.merged.org_name
    }
    tag_context = {
      resource_name = local.merged.resource_scope.name
    }
  }
)))
