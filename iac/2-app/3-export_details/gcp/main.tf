
locals {
  # Expose rendered common tags in provider.yaml under platform.custom_tags for downstream helm values.
  # Do not yamlencode() the whole map here. When interpolated into the heredoc, multi-line yamlencode output can mis-indent the first map entry flush-left.
  # Emit one indented line per key. jsonencode() values are valid YAML scalars.
  custom_tags_block = length(local.rendered_tags) > 0 ? join("\n", concat(
    ["  custom_tags:"],
    [for k in sort(keys(local.rendered_tags)) : format("    %s: %s", k, jsonencode(local.rendered_tags[k]))]
  )) : "  custom_tags: {}"

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

  # evalm8 lakeFS storage for provider.yaml, emitted under platform only when set (stack not router).
  # type is the storage backend (pvc or gcs on GCP). The helmfile maps it to the lakefs chart objectStorage.
  evalm8_storage_block = trimspace(var.evalm8_lakefs_bucket) != "" ? "  evalm8:\n    storage:\n      type: \"${var.evalm8_storage_type}\"\n      bucket: \"${var.evalm8_lakefs_bucket}\"" : ""

  # Stack selector consumed by k8s/helmfile.yaml.gotmpl (evalm8 | router | both). Emitted only when set.
  # An absent key makes helmfile deploy every stack (its documented default). This replaces the manual stack edit that each regen used to wipe.
  stack_block = trimspace(var.stack) != "" ? "stack: ${var.stack}\n\n" : ""

  platform_block = <<-EOT
# Global config and platform provider (GCP)
# Combined with resources.yaml and artifacts.yaml via helmfile

${local.stack_block}environment: ${var.environment}
${local.monitoring_block}
platform:
  provider: GCP
${local.custom_tags_block}
  gcp:
    secretsProjectId: "${var.project_id}"
    storage_configs:
      bucket: "${var.storage_bucket}"
${local.evalm8_storage_block}
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
