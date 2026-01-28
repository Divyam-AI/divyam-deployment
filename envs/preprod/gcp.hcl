#----------------------------------------------
# Preprod environment GCP-specific settings
# Migrated from divyam_router_cd/deployment/envs/preprod.hcl
#----------------------------------------------
locals {
  common_vars = {
    environment           = "preprod"
    region                = "asia-south1"
    project_id            = get_env("GCP_PROJECT_ID", "pre-production-project")
    ci_cd_service_account = get_env("GCP_CI_CD_SERVICE_ACCOUNT", "244819244005-compute@developer.gserviceaccount.com")
  }

  derived_vars = {
    k8s_cluster_name = "${local.common_vars.environment}-1-${local.common_vars.region}"
  }

  alerts = {
    enabled      = true
    exclude_list = ["router_elb_5xx_errors", "superset_elb_5xx_errors"]
  }

  cloud_apis = {
    enabled = true
    apis = [
      "compute.googleapis.com",
      "container.googleapis.com",
      "sql-component.googleapis.com",
      "artifactregistry.googleapis.com",
      "cloudbuild.googleapis.com",
      "iam.googleapis.com",
      "servicenetworking.googleapis.com",
      "dns.googleapis.com",
      "secretmanager.googleapis.com",
      "certificatemanager.googleapis.com",
      "networkmanagement.googleapis.com",
      "iap.googleapis.com",
    ]
  }

  notification_channels = {
    enabled           = true
    pager_enabled     = false
    pager_webhook_url = ""
    gchat_enabled     = true
    gchat_space_id    = "AAAAhcpI3S8"
    email_enabled     = false
    email_alert_email = ""
  }

  cloudsql = {
    enabled          = false
    instance_name    = "divyam-${local.common_vars.environment}-cloudsql"
    divyam_db_user   = "divyam-preprod"
    vpc_network      = "projects/${local.common_vars.project_id}/global/networks/default"
    vpc_network_name = "default"
  }

  ssl_cert = {
    enabled                 = false
    ssl_certificate_name    = ""
    ssl_certificate_domains = []
  }

  log_storage = {
    enabled        = true
    retention_days = 3
  }

  proxy_subnet = {
    enabled           = true
    network_self_link = "projects/${local.common_vars.project_id}/global/networks/default"
    subnet_name       = "proxy-only-subnet"
    ip_cidr_range     = "10.1.0.0/26"
  }

  gke = {
    enabled  = true
    clusters = {
      "${local.derived_vars.k8s_cluster_name}" = {
        region                   = local.common_vars.region
        release_channel          = "REGULAR"
        network                  = "projects/${local.common_vars.project_id}/global/networks/default"
        subnetwork               = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/default"
        cluster_ipv4_cidr        = "/21"
        services_ipv4_cidr       = "/25"
        additional_pod_range_names = []
        enable_private_nodes     = true
        enable_private_endpoint  = false
        master_authorized_networks_cidr = [
          {
            cidr_block   = "0.0.0.0/0"
            display_name = "Allow all (dev)"
          }
        ]
        binauthz_evaluation_mode = "DISABLED"
        dns_scope                = "VPC_SCOPE"
        dns_domain               = local.derived_vars.k8s_cluster_name
        enable_workload_logs     = true
        enable_cluster_logs      = true
      }
    }
  }

  cloud_build = {
    enabled         = false
    shared_vpc_name = "projects/${local.common_vars.project_id}/global/networks/default"
  }

  iam_bindings = {
    enabled = true

    artifact_registry = {
      artifact_registry_project        = "prod-benchmarking"
      artifact_registry_project_region = local.common_vars.region
      create_iam                       = true
      artifact_repositories            = ["divyam-router-helm-as1", "divyam-router-docker-as1", "divyam-docker-prod-as1", "divyam-docker-dev-as1", "divyam-helm-dev-as1"]
      service_account                  = ""
    }

    ci_cd = {
      create_iam      = true
      service_account = local.common_vars.ci_cd_service_account
      bucket_access   = false
    }

    prometheus_metric_writer = {
      create_iam      = true
      service_account = ""
    }

    default_node_service_account = {
      create_iam      = true
      service_account = ""
    }

    kafka_connect = {
      create_sa       = true
      namespace       = "kafka-${local.common_vars.environment}-ns"
      service_account = "kafka-${local.common_vars.environment}-connect"
    }

    billing = {
      create_sa          = true
      namespace          = "billing-${local.common_vars.environment}-ns"
      service_account    = "billing-${local.common_vars.environment}-sa"
      billing_project_id = "divyam-production"
      billing_dataset_id = "divyam_billing_bq_export"
    }

    eval = {
      create_sa       = true
      namespace       = "eval-${local.common_vars.environment}-ns"
      service_account = "eval-${local.common_vars.environment}-sa"
    }

    selector_training = {
      create_sa       = true
      namespace       = "selector-training-${local.common_vars.environment}-ns"
      service_account = "selector-training-${local.common_vars.environment}-sa"
      bucket_name     = "divyam-${local.common_vars.environment}-gcs-router-raw-logs"
    }

    router_controller = {
      create_sa       = true
      namespace       = "router-controller-${local.common_vars.environment}-ns"
      service_account = "gke-router-controller-${local.common_vars.environment}"
    }

    secrets_accessor = {
      create_sa       = true
      service_account = "secrets-accessor-${local.common_vars.environment}-sa"
    }

    ksa_bindings_for_secret_access = [
      { namespace = "billing-${local.common_vars.environment}-ns", name = "billing-${local.common_vars.environment}-sa" }
    ]
  }

  secrets = {
    enabled                     = false
    divyam_db_user_name         = local.cloudsql.divyam_db_user
    divyam_clickhouse_user_name = "default"
  }

  nat = {
    enabled         = true
    router_name     = "egress-nat-router-preprod"
    network         = "projects/${local.common_vars.project_id}/global/networks/default"
    nat_config_name = "egress-nat-config-preprod"
    nat_subnetworks = [
      {
        name  = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/default"
        cidrs = ["ALL_IP_RANGES"]
      }
    ]
  }

  static_addr = {
    enabled                = false
    address_name           = ""
    dashboard_address_name = ""
    test_address_name      = ""
  }

  elb = {
    enabled                   = false
    create_public_lb          = true
    ssl_certificate_id        = null
    static_ip_name            = "divyam-${local.common_vars.environment}-test-elb-static-ip"
    cloud_armor_policy_id     = "router-controller-${local.common_vars.environment}-cloud-armor-policy"
    backend_service_name      = "divyam-router-${local.common_vars.environment}-elb-backend"
    target_proxy_name         = "divyam-router-${local.common_vars.environment}-target_proxy"
    gke_neg_names = [
      "divyam-neg-${local.common_vars.environment}-${local.common_vars.region}-a",
      "divyam-neg-${local.common_vars.environment}-${local.common_vars.region}-b",
      "divyam-neg-${local.common_vars.environment}-${local.common_vars.region}-c"
    ]
    gke_neg_zones = [
      "${local.common_vars.region}-a",
      "${local.common_vars.region}-b",
      "${local.common_vars.region}-c"
    ]
    network    = "projects/${local.common_vars.project_id}/global/networks/default"
    subnetwork = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/default"
  }

  bastion_host = {
    enabled      = false
    bastion_name = "divyam-${local.common_vars.environment}-bastion"
    machine_type = "e2-micro"
    region       = local.common_vars.region
    zone         = "${local.common_vars.region}-a"
    tags         = ["allow-public-ssh"]
    network      = "projects/${local.common_vars.project_id}/global/networks/default"
    subnetwork   = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/default"
  }

  security = {
    enabled                               = false
    rate_limit_ip_ranges                  = ["*"]
    bad_ip_ranges                         = ["203.0.113.0/24"]
    rate_limit_threshold_count            = 100
    rate_limit_threshold_interval_sec     = 60
    rate_limit_ban_threshold_count        = 200
    rate_limit_ban_threshold_interval_sec = 300
    rate_limit_ban_duration_sec           = 600
  }

  gcs = {
    enabled                     = true
    bucket_location             = local.common_vars.region
    raw_router_logs_bucket_name = "divyam-${local.common_vars.environment}-gcs-router-raw-logs"
  }

  shared_vpc = {
    enabled         = false
    host_project_id = local.common_vars.project_id
    network_name    = "shared-vpc-network"
    subnets = [
      {
        subnet_name = "subnet-01"
        subnet_ip   = ""
      }
    ]
    secondary_ranges = {}
  }

  shared_vpc_service_project = {
    enabled            = false
    host_project_id    = local.common_vars.project_id
    service_project_id = local.common_vars.project_id
  }

  helm_charts = {
    enabled          = true
    k8s_cluster_name = local.derived_vars.k8s_cluster_name
    namespace_names = [
      "router-controller-${local.common_vars.environment}-ns",
      "router-dashboard-${local.common_vars.environment}-ns",
      "qdrant-${local.common_vars.environment}-ns",
      "infinity-${local.common_vars.environment}-ns",
      "route-selector-${local.common_vars.environment}-ns",
      "postgres-${local.common_vars.environment}-ns",
      "airflow-${local.common_vars.environment}-ns",
      "otel-collector-${local.common_vars.environment}-ns",
      "mysql-${local.common_vars.environment}-ns",
      "clickhouse-${local.common_vars.environment}-ns",
      "kafka-${local.common_vars.environment}-ns",
      "superset-${local.common_vars.environment}-ns",
      "external-secrets-operator-${local.common_vars.environment}-ns",
      "billing-${local.common_vars.environment}-ns",
      "eval-${local.common_vars.environment}-ns",
      "selector-training-${local.common_vars.environment}-ns",
      "redis-${local.common_vars.environment}-ns",
    ]
    values_file_path = ""
    chart_path       = ""
  }
}
