# Example: cloud-native alerts for a custom Kubernetes cluster on Azure (k8s.create = false).
# Export metrics via Prometheus remote_write; set AZURE_MONITOR_WORKSPACE_NAME before apply.

locals {
  cloud_provider = "azure"
  env_name       = "dev"
  org_name       = ""
  region         = "centralindia"
  zone           = "centralindia-1"

  deployment_prefix = "divyam-${local.env_name}"

  common_tags = {
    environment   = "#{environment}"
    resource_name = "#{resource_name}"
  }

  resource_scope = {
    create = false
    name   = get_env("SANDBOX_AZURE_RESOURCE_GROUP", "divyam-bkt-preprod-rg")
  }

  apis    = { enabled = false }
  vnet    = { create = false, name = "sandbox-vnet", scope_name = local.resource_scope.name, region = local.region, zone = local.zone, address_space = ["10.0.0.0/16"], subnet = { create = false, name = "sandbox-subnet" }, app_gw_subnet = { create = false, name = "sandbox-appgw-subnet" }, shared_vpc_host = false, service_project_ids = [] }
  nat     = { create = false, nat_gateway_name = "sandbox-nat", nat_public_ip_name = "sandbox-nat-ip" }
  bastion = { create = false, bastion_name = "sandbox-bastion" }
  tfstate = { create = false, local_state = true, bucket_name = "sandbox-tfstate", region = local.region, zone = local.zone, scope_name = local.resource_scope.name }

  k8s = {
    create                 = false
    name                   = "custom-k8s"
    kubernetes_version     = "1.34"
    node_provisioning_mode = "Auto"
    node_pools             = { default = { instance_type = "Standard_D4s_v3", spot_instance = false, auto_scaling = false, count = 1 }, additional = {} }
    observability = {
      enable_logs         = true
      enable_metrics      = true
      logs_retention_days = 7
    }
    release_channel          = "stable"
    setup_kubectl_on_bastion = false
  }

  monitoring = {
    create   = true
    provider = "cloud_native"
    native = {
      enable_metrics               = true
      enable_logs                  = true
      create_amw                   = false
      azure_monitor_workspace_name = get_env("SANDBOX_AZURE_MONITOR_WORKSPACE_NAME", "")
      azure_monitor_workspace_id   = null
      grafana_endpoint             = get_env("SANDBOX_GRAFANA_ENDPOINT", "")
    }
  }

  datadog = { enabled = false }

  iam_bindings = { create = false }

  alerts = {
    create                         = true
    enabled                        = true
    exclude_list                   = []
    webhook_urls                   = compact(split(",", get_env("NOTIFICATION_WEBHOOK_URLS", "")))
    webhook_custom_payload_enabled = true
    webhook_custom_payload         = null
    notify_no_data                 = true
    no_data_timeframe              = 15
    renotify_interval              = 30
  }

  # Private-registry image-pull auth (deployment-wide): create + inject the docker-auth secret.
  image_pull_secret_enabled = true

  export_details = {
    cluster_domain = ""
    output_dir     = "k8s/helm-values"
  }

  cloudsql          = { create = false, instance_name = "${local.deployment_prefix}-cloudsql" }
  outputs_file_path = "outputs/outputs-${local.deployment_prefix}.yaml"
}
