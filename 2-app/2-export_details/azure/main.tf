terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}

locals {
  key_vault_uri = "https://${var.key_vault_name}.vault.azure.net/"

  wif_client_id_lines = join("\n", [
    for name, client_id in var.wif_client_id_map : "        ${name}: \"${client_id}\""
  ])

  platform_block = <<-EOT
# Global config and platform provider (Azure)
# Combined with resources.yaml and artifacts.yaml via helmfile

environment: ${var.environment}
platform:
  provider: AZURE
  azure:
    keyVaultUri: "${local.key_vault_uri}"
    storage_configs:
      container: "${var.storage_container}"
      storage_account: "${var.storage_account}"
    wif:
      tenantID: "${var.tenant_id}"
      clientIdMap:
${local.wif_client_id_lines}

clusterDomain: "${var.cluster_domain}"

imagePullSecretConfig:
  enabled: ${var.image_pull_secret_enabled}
EOT

  databases_block = <<-EOT

databases:
  mysql:
    host: "${var.mysql_host}"
    port: ${var.mysql_port}
    database: "${var.mysql_database}"
EOT

  provider_yaml_content = var.cloudsql_created ? "${local.platform_block}${local.databases_block}" : local.platform_block
}

resource "local_file" "provider_yaml" {
  filename        = var.output_path
  content         = local.provider_yaml_content
  file_permission = "0644"
}
