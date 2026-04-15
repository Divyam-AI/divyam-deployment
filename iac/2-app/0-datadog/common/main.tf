# Datadog Operator Helm release + API key secret + DatadogAgent CR. Shared by Azure and GCP;
# callers must configure kubernetes and helm providers in the root module.

locals {
  datadog_namespace = "datadog"
  datadog_release   = "datadog-operator"

  # Shared exclusions are always applied. Granular exclusions are additive.
  datadog_logs_exclude_namespaces    = distinct(concat(var.datadog_exclude_namespaces, var.datadog_exclude_namespaces_logs))
  datadog_metrics_exclude_namespaces = distinct(concat(var.datadog_exclude_namespaces, var.datadog_exclude_namespaces_metrics))

  # Datadog expects space-separated kube_namespace:<name> filters.
  datadog_logs_namespace_excludes    = join(" ", formatlist("kube_namespace:%s", local.datadog_logs_exclude_namespaces))
  datadog_metrics_namespace_excludes = join(" ", formatlist("kube_namespace:%s", local.datadog_metrics_exclude_namespaces))

  # Credentials reference the Secret resource; only merge when enabled so Terraform does not
  # evaluate kubernetes_secret_v1.datadog_secret["enabled"] when for_each on that resource is empty.
  datadog_agent_global = merge(
    {
      clusterName = var.cluster_name
      site        = var.datadog_site
      registry    = var.datadog_docker_registry
      tags = [
        "env:${var.datadog_env}",
      ]
      containerExcludeLogs    = local.datadog_logs_namespace_excludes
      containerExcludeMetrics = local.datadog_metrics_namespace_excludes
    },
    var.datadog_enabled ? {
      credentials = {
        apiSecret = {
          secretName = kubernetes_secret_v1.datadog_secret["enabled"].metadata[0].name
          keyName    = "api-key"
        }
      }
    } : {}
  )

  datadog_agent_spec_base = {
    global = local.datadog_agent_global
    features = {
      clusterChecks = {
        enabled = true
      }
      orchestratorExplorer = {
        enabled = true
      }
      logCollection = {
        enabled             = true
        containerCollectAll = true
      }
    }
  }

  # Optional AKS-style node agent image override; omitted on GCP unless enabled explicitly.
  datadog_agent_spec = merge(
    local.datadog_agent_spec_base,
    var.node_agent_jmx_enabled ? {
      override = {
        nodeAgent = {
          image = {
            jmxEnabled = true
          }
        }
      }
    } : {}
  )
}

# Ensure the namespace exists before Helm / Secrets. Server-side apply is idempotent: if `datadog`
# already exists (Helm, manual, etc.), apply succeeds without error. If you previously had
# kubernetes_namespace_v1 for this ns in state, `tofu state rm` that resource before switching here
# so Terraform does not plan to destroy the namespace.
resource "kubectl_manifest" "datadog_namespace" {
  for_each = var.datadog_enabled ? { "enabled" = true } : {}

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = local.datadog_namespace
    }
  })

  validate_schema   = false
  server_side_apply = true
}

resource "helm_release" "datadog_operator" {
  for_each = var.datadog_enabled ? { "enabled" = true } : {}

  name             = local.datadog_release
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog-operator"
  namespace        = local.datadog_namespace
  create_namespace = false
  timeout          = 600

  depends_on = [kubectl_manifest.datadog_namespace[each.key]]
}

resource "kubernetes_secret_v1" "datadog_secret" {
  for_each = var.datadog_enabled ? { "enabled" = true } : {}

  metadata {
    name      = "datadog-secret"
    namespace = local.datadog_namespace
  }

  data = {
    "api-key" = var.datadog_api_key
  }

  type = "Opaque"

  depends_on = [kubectl_manifest.datadog_namespace[each.key]]
}

# kubectl_manifest + validate_schema=false: DatadogAgent CRD appears only after the operator Helm
# chart is applied; kubernetes_manifest fails at plan with "CRD may not be installed".
resource "kubectl_manifest" "datadog_agent" {
  for_each = var.datadog_enabled ? { "enabled" = true } : {}

  yaml_body = yamlencode({
    apiVersion = "datadoghq.com/v2alpha1"
    kind       = "DatadogAgent"
    metadata = {
      name      = "datadog"
      namespace = local.datadog_namespace
    }
    spec = local.datadog_agent_spec
  })

  validate_schema = false

  depends_on = [
    kubectl_manifest.datadog_namespace[each.key],
    helm_release.datadog_operator,
    kubernetes_secret_v1.datadog_secret,
  ]
}
