locals {
  artifacts_preprocessed = yamldecode(file(var.artifacts_path))

  filtered_charts = [
    # Filter out excluded charts.
    for chart_name, chart in local.artifacts_preprocessed["helm_charts"] : { chart_name = chart_name, chart = chart } if !(contains(var.exclude_charts, chart_name))
  ]

  # Convert the filtered list of pairs back into a map
  charts = { for pair in local.filtered_charts : pair.chart_name => pair.chart }

  image_override_values = {
    for chart_name, chart in local.charts : chart_name => concat(
      lookup(chart, "image_override", null) != null ?
      ["images:\n  ${chart_name}: ${lookup(chart.image_override, "use_divyam_registry", false) == true ? "${var.divyam_docker_registry_url}/${chart.image_override.name}:${chart.image_override.tag}" : "${chart.image_override.name}:${chart.image_override.tag}"}"]
    : [])
  }

  chart_values = {
    for chart_name, chart in local.charts : chart_name => concat(
      # Optional shared values.yaml
      can(file("${var.values_dir_path}/${chart_name}/values.yaml")) ?
      [file("${var.values_dir_path}/${chart_name}/values.yaml")] : [],

      # Optional env-specific values.yaml
      can(file("${var.values_dir_path}/${chart_name}/${var.environment}-values.yaml")) ?
      [file("${var.values_dir_path}/${chart_name}/${var.environment}-values.yaml")] : [],

      # The last value takes precedence.
      local.image_override_values[chart_name]
    )
  }

  service_account_meta = {
    for chart_name, chart in local.charts : chart_name => yamlencode({
      "serviceAccountMeta" = {
        "imagePullSecrets" = [{ "name" : "divyam-gar-sa-key" }]
        "annotations" = (
          lookup(chart, "uai_client_id_name", null) != null ? {
            "azure.workload.identity/client-id" = var.uai_client_ids[chart.uai_client_id_name]
          } : {}
        )
      }
    })
  }

  pod_meta = {
    for chart_name, chart in local.charts : chart_name => lookup(chart, "uai_client_id_name", null) != null ? yamlencode({
      "podMeta" = {
        "labels" = {
          "azure.workload.identity/use" = tostring(true)
        }
      }
      }
    ) : null
  }

  azure_key_vault_secrets = toset(flatten([
    for chart in local.charts : concat(
      lookup(chart, "az_secret_inject", null) != null ? [for secret in chart["az_secret_inject"] : secret["secret_name"]] : []
    )
  ]))

  # Detect missing environment-specific values file (for logging only)
  missing_env_values = {
    for chart_name, chart in local.charts : chart_name => true
    if !can(file("${var.values_dir_path}/${chart_name}/${var.environment}-values.yaml"))
  }
}

resource "null_resource" "warn_missing_env_values" {
  for_each = local.missing_env_values

  triggers = {
    message = "Warning: Missing ${var.environment}-values.yaml for chart '${each.key}' in ${var.values_dir_path}/${each.key}/"
  }

  provisioner "local-exec" {
    command = "echo ${self.triggers.message}"
  }
}

# Read the GAR SA key.
data "azurerm_key_vault_secret" "gar_sa_key" {
  name         = "divyam-gar-sa-key"
  key_vault_id = var.azure_key_vault_id
}

# Get an access token for GAR using the SA key.
data "external" "gcp_token" {
  program = ["${path.module}/gar_access_token.sh"]

  query = {
    GCP_SA_KEY_JSON = data.azurerm_key_vault_secret.gar_sa_key.value
  }
}

provider "kubernetes" {
  host                   = var.aks_kube_config[var.aks_cluster_name].host
  client_certificate     = base64decode(var.aks_kube_config[var.aks_cluster_name].client_certificate)
  client_key             = base64decode(var.aks_kube_config[var.aks_cluster_name].client_key)
  cluster_ca_certificate = base64decode(var.aks_kube_config[var.aks_cluster_name].cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = var.aks_kube_config[var.aks_cluster_name].host
    client_certificate     = base64decode(var.aks_kube_config[var.aks_cluster_name].client_certificate)
    client_key             = base64decode(var.aks_kube_config[var.aks_cluster_name].client_key)
    cluster_ca_certificate = base64decode(var.aks_kube_config[var.aks_cluster_name].cluster_ca_certificate)
  }

  registries = [
    {
      url      = var.divyam_helm_registry_url
      username = "oauth2accesstoken" # Special username for token authentication
      password = data.external.gcp_token.result.token
    }
  ]
}

# Fetch the secrets from azure key vault.
data "azurerm_key_vault_secret" "secrets" {
  for_each = local.azure_key_vault_secrets

  name         = each.key
  key_vault_id = var.azure_key_vault_id
}

resource "helm_release" "divyam_deploy" {
  for_each   = local.charts
  name       = "${replace((lookup(each.value, "name", null) != null ? each.value["name"] : each.key), "_", "-")}-${var.environment}"
  repository = lookup(each.value, "repository", null) != null ? each.value["repository"] : var.divyam_helm_registry_url
  chart      = each.value.chart
  version    = each.value.version
  namespace  = lookup(each.value, "namespace", null) != null ? each.value["namespace"] : "${each.value["namespace_prefix"]}-${var.environment}-ns"

  # TODO: A regression in terraform helm resource does not allow upgrade/install support. Will be fixed in next release of helm
  #  See: https://github.com/hashicorp/terraform-provider-helm/pull/1675
  #upgrade_install = true
  replace       = var.helm_release_replace_all || lookup(each.value, "replace", false)
  recreate_pods = var.helm_release_recreate_pods_all || lookup(each.value, "recreate_pods", false)
  force_update  = var.helm_release_force_update_all || lookup(each.value, "force_update", false)

  values = concat(
    local.chart_values[each.key],
    [
      # Service account metadata.
      local.service_account_meta[each.key]
    ],
    # Pod metadata.
    local.pod_meta[each.key] != null ? [local.pod_meta[each.key]] : []
  )

  # Common chart values.
  set = concat(
    [
      {
        name  = "environment"
        value = var.environment
      },
      {
        name  = "divyam_platform"
        value = "AZURE"
      }
    ],

    lookup(each.value, "share_key_vault_uri", false) == true ? [{
      name  = "azure_key_vault_uri"
      value = var.azure_key_vault_uri
    }] : [],

    lookup(each.value, "share_dns_names", false) == true ? concat(
      var.router_dns_zone != null ? [{
        name  = "router_dns_name"
        value = var.router_dns_zone
      }] : [],
      var.dashboard_dns_zone != null ? [{
        name  = "dashboard_dns_name"
        value = var.dashboard_dns_zone
      }] : [],
      var.app_gateway_tls_enabled ? [{
        name  = "app_gw_tls_enabled"
        value = var.app_gateway_tls_enabled
        },
        {
          name  = "app_gateway_certificate_name"
          value = var.app_gateway_certificate_name
        }
      ] : []
    ) : [],

    lookup(each.value, "share_router_logs_storage_account_name", null) != null ? [{
      name  = each.value.share_router_logs_storage_account_name
      value = var.azure_router_logs_storage_account_name
    }] : [],

    lookup(each.value, "share_router_logs_container_name", null) != null ? [{
      name  = each.value.share_router_logs_container_name
      value = var.azure_router_logs_container_name
    }] : [],
  )

  # Inject secrets into helm release
  set_sensitive = concat([
    for inject in lookup(each.value, "az_secret_inject", []) : {
      name  = inject.chart_variable_name
      value = data.azurerm_key_vault_secret.secrets[inject.secret_name].value
    }
    ],

    lookup(each.value, "share_router_logs_storage_connection_string", null) != null ? [{
      name  = each.value.share_router_logs_storage_connection_string
      value = var.azure_router_logs_storage_connection_string
    }] : []
  )
}
