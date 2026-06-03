# Example: cloud-native alerts for a custom Kubernetes cluster on GCP (k8s.create = false).
# Export metrics to GMP first — see iac/README.md (Custom Kubernetes).

locals {
  cloud_provider = "gcp"
  env_name       = "dev"
  org_name       = ""
  region         = "asia-south1"
  zone           = "asia-south1-c"

  deployment_prefix = "divyam-${local.env_name}"

  common_tags = {
    environment   = "divyam-env-#{environment}"
    resource_name = "#{resource_name}"
  }

  resource_scope = {
    create = false
    name   = "pre-production-project"
  }

  apis  = { enabled = false }
  vnet  = { create = false, name = "default", scope_name = "pre-production-project", region = local.region, zone = local.zone, address_space = ["10.0.0.0/16"], subnet = { create = false, name = "default" }, app_gw_subnet = { create = false, name = "proxy-only-subnet" }, shared_vpc_host = false, service_project_ids = [] }
  nat   = { create = false, router_name = "sandbox-router", nat_config_name = "sandbox-nat" }
  bastion = { create = false, bastion_name = "sandbox-bastion" }
  tfstate = { create = false, local_state = true, bucket_name = "sandbox-tfstate", region = local.region, zone = local.zone, scope_name = local.resource_scope.name }

  k8s = {
    create = false
    name   = "custom-k8s"
    kubernetes_version = "1.34"
    node_provisioning_mode = "Auto"
    node_pools = { default = { instance_type = "e2-standard-4", spot_instance = false, auto_scaling = false, count = 1 }, additional = {} }
    observability = {
      enable_logs         = true
      enable_metrics      = true
      logs_retention_days = 7
    }
    release_channel = "REGULAR"
    setup_kubectl_on_bastion = false
  }

  monitoring = {
    create   = true
    provider = "cloud_native"
    native = {
      enable_metrics            = true
      enable_logs               = true
      logs_retention_days       = 7
      manage_project_log_bucket = false
      gcp_project_id            = "pre-production-project"
      create_amw                = true
    }
  }

  datadog = { enabled = false }

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
