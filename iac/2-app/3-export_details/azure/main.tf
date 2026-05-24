locals {
  key_vault_uri = "https://${var.key_vault_name}.vault.azure.net/"
  # Expose rendered common tags in provider.yaml under platform.custom_tags for downstream helm values.
  # Do not yamlencode() the whole map here: when interpolated into the heredoc, multi-line yamlencode output
  # can mis-indent (first map entry flush-left). Emit one indented line per key; jsonencode() values are valid YAML scalars.
  custom_tags_block = length(local.rendered_tags) > 0 ? join("\n", concat(
    ["  custom_tags:"],
    [for k in sort(keys(local.rendered_tags)) : format("    %s: %s", k, jsonencode(local.rendered_tags[k]))]
  )) : "  custom_tags: {}"

  wif_client_id_lines = join("\n", [
    for name, client_id in var.wif_client_id_map : "        ${name}: \"${client_id}\""
  ])

  # Export top-level monitoring config used by helmfile global values merge.
  # provider is emitted only when explicitly set (currently datadog when enabled).
  monitoring_block = var.monitoring_enabled ? (
    trimspace(var.monitoring_provider) != "" ?
    <<-EOT
monitoring:
  metrics:
    enabled: true
  provider: "${var.monitoring_provider}"

EOT
    :
    <<-EOT
monitoring:
  metrics:
    enabled: true

EOT
  ) : <<-EOT
monitoring:
  metrics:
    enabled: false

EOT

  platform_block = <<-EOT
# Global config and platform provider (Azure)
# Combined with resources.yaml and artifacts.yaml via helmfile

environment: ${var.environment}
${local.monitoring_block}
platform:
  provider: AZURE
${local.custom_tags_block}
  azure:
    keyVaultUri: "${local.key_vault_uri}"
    storage_configs:
      container: "${var.storage_container}"
      storage_account: "${var.storage_account}"
    wif:
      tenantID: "${var.tenant_id}"
      clientIdMap:
${local.wif_client_id_lines}

ingress:
  deploy: ${var.ingress_deploy}
  external: ${var.ingress_external}
  domain:
    router: "${var.router_ingress_domain}"
    dashboard: "${var.dashboard_ingress_domain}"
    controlplane: "${var.controlplane_ingress_domain}"
  azure:
    tls_enabled: ${var.ingress_tls_enabled}
    certificate_name: "${var.ingress_certificate_name}"

imagePullSecretConfig:
  enabled: ${var.image_pull_secret_enabled}

deployment_mode: "${var.deployment_mode}"
clusterDomain: "${var.cluster_domain}"

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
