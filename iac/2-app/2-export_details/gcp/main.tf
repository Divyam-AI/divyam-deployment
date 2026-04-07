
locals {
  platform_block = <<-EOT
# Global config and platform provider (GCP)
# Combined with resources.yaml and artifacts.yaml via helmfile

environment: ${var.environment}
platform:
  provider: GCP
  gcp:
    secretsProjectId: "${var.project_id}"
    storage_configs:
      bucket: "${var.storage_bucket}"

clusterDomain: "${var.cluster_domain}"
deployment_mode: "${var.deployment_mode}"

imagePullSecretConfig:
  enabled: ${var.image_pull_secret_enabled}

ingress:
  deploy: ${var.ingress_deploy}
  external: ${var.ingress_external}
  domain:
    router: "${var.router_ingress_domain}"
    dashboard: "${var.dashboard_ingress_domain}"
    controlplane: "${var.controlplane_ingress_domain}"
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
