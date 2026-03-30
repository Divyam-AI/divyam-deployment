terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}

locals {
  env_yaml_content = <<-EOT
# Global config and platform provider (GCP)
# Combined with artifacts.yaml and resources.yaml via helmfile

environment: ${var.environment}
platform:
  provider: GCP
  gcp:
    secretsProjectId: "${var.project_id}"
    storage_configs:
      bucket: "${var.storage_bucket}"

clusterDomain: "${var.cluster_domain}"

imagePullSecretConfig:
  enabled: ${var.image_pull_secret_enabled}
EOT
}

resource "local_file" "provider_yaml" {
  filename        = var.output_path
  content         = local.env_yaml_content
  file_permission = "0644"
}
