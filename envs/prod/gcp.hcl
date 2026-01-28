#----------------------------------------------
# Prod environment GCP-specific settings
# Migrated from divyam_router_cd/deployment/envs/prod.hcl
#----------------------------------------------
locals {
  common_vars = {
    environment                            = "prod"
    region                                 = "asia-south1"
    project_id                             = get_env("GCP_PROJECT_ID", "divyam-production")
    ssl_certificate_domain                 = "api.divyam.ai"
    ci_cd_service_account                  = get_env("GCP_CI_CD_SERVICE_ACCOUNT", "244819244005-compute@developer.gserviceaccount.com")
    ci_cd_artifact_registry_project        = "prod-benchmarking"
    ci_cd_artifact_registry_project_region = "asia-south1"
    ci_cd_artifact_repositories            = ["divyam-router-helm-as1", "divyam-router-docker-as1", "divyam-docker-prod-as1"]
    enable_notification_alerts             = true
    notification_pager_webhook_url         = "https://events.zenduty.com/integration/vv0kf/stackdriver/2240d4f2-5c47-4a3a-9328-571bab2a8cfc/"
    notification_gchat_space_id            = "AAAAu4HGrxQ"
    notification_email_alert_email         = "divyam@divyam.ai"
  }

  derived_vars = {
    k8s_cluster_name = "divyam-gke-${local.common_vars.environment}-1-${local.common_vars.region}"
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

  shared_vpc = {
    enabled         = true
    host_project_id = local.common_vars.project_id
    network_name    = "divyam-${local.common_vars.environment}-shared-vpc-network"
    subnets = [
      {
        subnet_name = "divyam-${local.common_vars.environment}-subnet"
        subnet_ip   = "10.148.0.0/20"
        region      = local.common_vars.region

        secondary_ranges = [
          {
            range_name    = "pods"
            ip_cidr_range = "10.148.32.0/20"
          },
          {
            range_name    = "services"
            ip_cidr_range = "10.148.48.0/20"
          },
          {
            range_name                  = "gke-divyam-gke-prod-1-asia-south1-pods-65270d8e"
            ip_cidr_range               = "10.7.152.0/21"
            reserved_internal_range     = "https://networkconnectivity.googleapis.com/v1/projects/divyam-production/locations/global/internalRanges/gke-divyam-gke-prod-1-asia-south1-pods-65270d8e"
          },
          {
            range_name    = "pods-extra"
            ip_cidr_range = "10.8.0.0/18"
          }
        ]
      }
    ]
  }

  bastion_host = {
    enabled      = true
    bastion_name = "divyam-${local.common_vars.environment}-bastion"
    machine_type = "e2-micro"
    region       = local.common_vars.region
    zone         = "${local.common_vars.region}-a"
    tags         = ["allow-public-ssh"]
    network      = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
    subnet       = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet"
  }

  cloudsql = {
    enabled          = false
    vpc_network_name = "divyam-${local.common_vars.environment}-shared-vpc-network"
    vpc_network      = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
    instance_name    = "divyam-${local.common_vars.environment}-cloudsql"
    divyam_db_user   = "divyam"
  }

  secrets = {
    enabled                     = false
    divyam_db_user_name         = local.cloudsql.divyam_db_user
    divyam_clickhouse_user_name = "default"
  }

  static_addr = {
    enabled                = true
    address_name           = "divyam-${local.common_vars.environment}-elb-static-ip"
    dashboard_address_name = "divyam-dashboard-${local.common_vars.environment}-elb-static-ip"
    test_address_name      = "divyam-${local.common_vars.environment}-test-elb-static-ip"
  }

  nat = {
    enabled         = true
    network         = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
    router_name     = "divyam-router-${local.common_vars.environment}-egress-nat-router"
    nat_config_name = "divyam-router-${local.common_vars.environment}-egress-nat-config"
    nat_subnetworks = [
      {
        name  = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet"
        cidrs = ["ALL_IP_RANGES"]
      }
    ]
  }

  ssl_cert = {
    enabled                 = true
    ssl_certificate_name    = "divyam-ai-router-${local.common_vars.environment}-ssl-cert"
    ssl_certificate_domains = [local.common_vars.ssl_certificate_domain]
  }

  security = {
    enabled                               = true
    cloud_armor_policy_name               = "router-controller-${local.common_vars.environment}-cloud-armor-policy"
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
    network    = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
    subnetwork = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet"
  }

  log_storage = {
    enabled        = true
    retention_days = 7
  }

  proxy_subnet = {
    enabled = false
  }

  gke = {
    enabled  = true
    clusters = {
      "${local.derived_vars.k8s_cluster_name}" = {
        region                     = local.common_vars.region
        release_channel            = "REGULAR"
        network                    = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
        subnetwork                 = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet"
        cluster_ipv4_cidr          = "/21"
        services_ipv4_cidr         = "/25"
        additional_pod_range_names = ["pods-extra", "pods"]
        enable_private_nodes       = true
        enable_private_endpoint    = false
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

  iam_bindings = {
    enabled = true

    ci_cd = {
      create_iam      = true
      service_account = local.common_vars.ci_cd_service_account
      bucket_access   = true
    }

    artifact_registry = {
      create_iam                       = true
      artifact_registry_project        = local.common_vars.ci_cd_artifact_registry_project
      artifact_registry_project_region = local.common_vars.ci_cd_artifact_registry_project_region
      artifact_repositories            = local.common_vars.ci_cd_artifact_repositories
      service_account                  = ""
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

    router_controller = {
      create_sa       = true
      namespace       = "router-controller-${local.common_vars.environment}-ns"
      service_account = "gke-router-controller-${local.common_vars.environment}-sa"
    }

    selector_training = {
      create_sa       = true
      namespace       = "selector-training-${local.common_vars.environment}-ns"
      service_account = "selector-training-${local.common_vars.environment}-sa"
      bucket_name     = "divyam-${local.common_vars.environment}-gcs-router-raw-logs"
    }

    secrets_accessor = {
      create_sa       = true
      service_account = "secrets-accessor-${local.common_vars.environment}-sa"
    }

    ksa_bindings_for_secret_access = [
      { namespace = "billing-${local.common_vars.environment}-ns", name = "billing-${local.common_vars.environment}-sa" }
    ]
  }

  cloud_build = {
    enabled         = false
    shared_vpc_name = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
  }

  alerts = {
    enabled      = local.common_vars.enable_notification_alerts
    exclude_list = []
  }

  notification_channels = {
    enabled           = local.common_vars.enable_notification_alerts
    pager_enabled     = true
    pager_webhook_url = local.common_vars.notification_pager_webhook_url
    gchat_enabled     = true
    gchat_space_id    = local.common_vars.notification_gchat_space_id
    email_enabled     = true
    email_alert_email = local.common_vars.notification_email_alert_email
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

  shared_vpc_service_project = {
    enabled            = false
    host_project_id    = local.common_vars.project_id
    service_project_id = "${local.common_vars.project_id}-shared-project"
  }

  # GCS remote state config
  gcs_remote_state = {
    bucket   = "divyam-production-terraform-state-bucket"
    project  = local.common_vars.project_id
    location = local.common_vars.region
  }
}
