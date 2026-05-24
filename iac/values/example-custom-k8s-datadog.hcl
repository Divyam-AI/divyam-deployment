# Example: Datadog on a custom Kubernetes cluster (not created by 1-k8s).
#
# Prerequisites:
#   - Cluster API reachable via kubeconfig (export KUBECONFIG or use default ~/.kube/config)
#   - k8s.create = false in this file
#   - datadog.custom_cluster_name matches {{cluster_name}} in 2-app/2-alerts/common/rules
#
# Copy and adjust resource_scope, env_name, and cluster names for your environment.

locals {
  cloud_provider = get_env("CLOUD_PROVIDER", "gcp")
  env_name       = "dev"
  org_name       = ""
  region         = local.cloud_provider == "azure" ? "centralindia" : "asia-south1"
  zone           = local.cloud_provider == "azure" ? "centralindia-1" : "asia-south1-c"

  deployment_prefix = "myorg-${local.env_name}"

  common_tags = {
    environment   = local.env_name
    resource_name = "#{resource_name}"
  }

  resource_scope = {
    create = false
    name   = get_env("CUSTOM_K8S_SCOPE_NAME", "your-gcp-project-or-azure-rg")
  }

  apis    = { enabled = false }
  vnet    = { create = false, name = "default", scope_name = local.resource_scope.name, region = local.region, zone = local.zone, address_space = ["10.0.0.0/16"], subnet = { create = false, name = "default" }, app_gw_subnet = { create = false, name = "default" }, shared_vpc_host = false, service_project_ids = [] }
  nat     = { create = false, router_name = "custom-router", nat_config_name = "custom-nat" }
  bastion = { create = false, bastion_name = "custom-bastion" }
  tfstate = { create = false, local_state = true, bucket_name = "custom-tfstate", region = local.region, zone = local.zone, scope_name = local.resource_scope.name }

  k8s = {
    create = false
    name   = "custom-k8s"
    kubernetes_version     = "1.34"
    node_provisioning_mode = "Auto"
    node_pools = { default = { instance_type = "e2-standard-4", spot_instance = false, auto_scaling = false, count = 1 }, additional = {} }
    observability = {
      enable_logs    = false
      enable_metrics = false
    }
    release_channel          = "REGULAR"
    setup_kubectl_on_bastion = false
  }

  monitoring = {
    create   = true
    provider = "datadog"
    native = {
      enable_metrics = false
      enable_logs    = false
    }
  }

  datadog = {
    enabled              = true
    site                 = "datadoghq.com"
    registry             = "gcr.io/datadoghq"
    env                  = local.env_name
    custom_cluster_name  = "custom-k8s"
    exclude_namespaces   = ["kube-system"]
    exclude_namespaces_logs    = []
    exclude_namespaces_metrics = []
  }

  iam_bindings = { create = false }

  alerts = {
    create       = true
    enabled      = true
    exclude_list = []
    webhook_urls = compact(split(",", get_env("NOTIFICATION_WEBHOOK_URLS", "")))
    webhook_custom_payload_enabled = true
    webhook_custom_payload         = null
    notify_no_data    = true
    no_data_timeframe = 15
    renotify_interval = 30
  }

  export_details = {
    cluster_domain            = ""
    image_pull_secret_enabled = false
    output_dir                = "k8s/helm-values"
  }

  cloudsql = { create = false, instance_name = "${local.deployment_prefix}-cloudsql" }
  outputs_file_path = "outputs/outputs-${local.deployment_prefix}.yaml"
}
