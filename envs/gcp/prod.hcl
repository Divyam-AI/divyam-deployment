locals {
  #########################################################################
  # Only change the below common_vars variables and should be able to deploy the infra without touching rest of the configs
  #########################################################################
  common_vars = {
    environment                             = "prod"
    region                                  = "asia-south1"
    project_id                              = "divyam-production"

    # If SSL domain is not required for router, ignore ssl_certificate_domain config and set ssl_cert.enabled to false
    ssl_certificate_domain                  = "api.divyam.ai" # or can set to "${local.common_vars.environment}-api.divyam.ai"

    # If CI-CD is not required, set ci_cd.create_iam, artifact_registry.enabled to false and ignore below ci_cd_* configs
    ci_cd_service_account                   = "244819244005-compute@developer.gserviceaccount.com" # Can overwrite the default service account from where artifacts will be pulled
    ci_cd_artifact_registry_project         = "prod-benchmarking"
    ci_cd_artifact_registry_project_region  = "asia-south1"
    ci_cd_artifact_repositories             = ["divyam-router-helm-as1", "divyam-router-docker-as1", "divyam-docker-prod-as1"]

    # If alert and notifications are not required, set enable_notification_alerts false and ignore notification_* configs
    enable_notification_alerts              = true  
    notification_pager_webhook_url          = "https://events.zenduty.com/integration/vv0kf/stackdriver/2240d4f2-5c47-4a3a-9328-571bab2a8cfc/"
    notification_gchat_space_id             = "AAAAu4HGrxQ"
    notification_email_alert_email          = "divyam@divyam.ai"

    # divyam_db_password=<SECURE_PASSWORD> # can add here or  can export TF_VAR_divyam_db_password=<SECURE_PASSWORD>
    #########################################################################
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
    enabled = true
    host_project_id = local.common_vars.project_id
    network_name    = "divyam-${local.common_vars.environment}-shared-vpc-network"
    subnets = [
      {
        subnet_name   = "divyam-${local.common_vars.environment}-subnet"
        subnet_ip     = "10.148.0.0/20"
        region        = local.common_vars.region

        secondary_ranges = [
          {
            range_name    = "pods"
            ip_cidr_range = "10.148.32.0/20"   # existing cluster pods
          },
          {
            range_name    = "services"
            ip_cidr_range = "10.148.48.0/20"   # existing cluster services
          },
          {
            range_name    = "gke-divyam-gke-prod-1-asia-south1-pods-65270d8e"
            ip_cidr_range = "10.7.152.0/21"  # <-- leave as-is (this is what cluster uses)
            reserved_internal_range = "https://networkconnectivity.googleapis.com/v1/projects/divyam-production/locations/global/internalRanges/gke-divyam-gke-prod-1-asia-south1-pods-65270d8e"
          },
          {
            range_name    = "pods-extra"
            ip_cidr_range = "10.8.0.0/18"  # new pods range
          }
        ]
      }
    ]
  }

  # Required for bastion host to access cloudsql instance and other resources
  bastion_host = {
    enabled        = true
    bastion_name   = "divyam-${local.common_vars.environment}-bastion"
    machine_type   = "e2-micro"
    region        = local.common_vars.region
    zone           = "${local.common_vars.region}-a"
    tags           = ["allow-public-ssh"]
    network        = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
    subnet         = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet"
  }

  cloudsql = {
    enabled        = false
    vpc_network_name = "divyam-${local.common_vars.environment}-shared-vpc-network"
    vpc_network    = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
    instance_name  = "divyam-${local.common_vars.environment}-cloudsql"
    divyam_db_user = "divyam"
    # for password do export TF_VAR_divyam_db_password=<SECURE_PASSWORD>
  }

  secrets = {
    # Set this to true to add secrets to secret manager, but need to export all the secret variables(var_*) 
    # defined in secrets/variables.tf as env variables. e.g. : export TF_VAR_divyam_db_password=<SECURE_PASSWORD>
    enabled = false     
    divyam_db_user_name = local.cloudsql.divyam_db_user
    divyam_clickhouse_user_name = "default"
    # for mysql password do export TF_VAR_divyam_db_password=<SECURE_PASSWORD>
    # for clickhouse password do export TF_VAR_divyam_clickhouse_password=<SECURE_PASSWORD>
    # for openai billing key do export TF_VAR_divyam_openai_billing_api_key=<SECURE_KEY>
  }

  static_addr = {
    enabled      = true
    address_name = "divyam-${local.common_vars.environment}-elb-static-ip"
    dashboard_address_name = "divyam-dashboard-${local.common_vars.environment}-elb-static-ip"
    test_address_name = "divyam-${local.common_vars.environment}-test-elb-static-ip"
  }

  nat = {
    enabled         = true
    network         = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
    router_name     = "divyam-router-${local.common_vars.environment}-egress-nat-router"
    nat_config_name = "divyam-router-${local.common_vars.environment}-egress-nat-config"
    # Add pods IP ranges to NAT
    nat_subnetworks = [
      {
        name  = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet",
        cidrs = ["ALL_IP_RANGES"]
      }
    ]
  }

  ssl_cert = {
    enabled                = true
    ssl_certificate_name   = "divyam-ai-router-${local.common_vars.environment}-ssl-cert"
    ssl_certificate_domains = [local.common_vars.ssl_certificate_domain]
  }

  security = {    
    enabled                             = true
    cloud_armor_policy_name = "router-controller-${local.common_vars.environment}-cloud-armor-policy"
    rate_limit_ip_ranges                = ["*"]
    bad_ip_ranges                       = ["203.0.113.0/24"]
    rate_limit_threshold_count          = 100
    rate_limit_threshold_interval_sec   = 60
    rate_limit_ban_threshold_count      = 200
    rate_limit_ban_threshold_interval_sec = 300
    rate_limit_ban_duration_sec         = 600
  }

  gcs = {
    enabled = true
    bucket_location = local.common_vars.region
    raw_router_logs_bucket_name = "divyam-${local.common_vars.environment}-gcs-router-raw-logs"
  }

  elb = {
    enabled = false
    create_public_lb = true
    ssl_certificate_id = null
    static_ip_name = "divyam-${local.common_vars.environment}-test-elb-static-ip" # static_addr.test_address_name
    cloud_armor_policy_id = "router-controller-${local.common_vars.environment}-cloud-armor-policy" # security.cloud_armor_policy_name
    backend_service_name = "divyam-router-${local.common_vars.environment}-elb-backend"
    target_proxy_name = "divyam-router-${local.common_vars.environment}-target_proxy"
    gke_neg_names = [ "divyam-neg-${local.common_vars.environment}-${local.common_vars.region}-a", 
                      "divyam-neg-${local.common_vars.environment}-${local.common_vars.region}-b", 
                      "divyam-neg-${local.common_vars.environment}-${local.common_vars.region}-c"]
    gke_neg_zones = [ "${local.common_vars.region}-a", 
                      "${local.common_vars.region}-b", 
                      "${local.common_vars.region}-c"]
    network = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"                   
    subnetwork = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet" # nat.subnet[0].name
    # Health check
  }

  log_storage = {
    enabled = true
    retention_days = 7
  }
  
  proxy_subnet = {
    enabled = false
  }

  gke = {
    enabled  = true
    clusters = {
      "${local.derived_vars.k8s_cluster_name}" = {
        region                   = local.common_vars.region
        release_channel          = "REGULAR"
        # Created above in shared vpc
        network                  = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
        subnetwork               = "projects/${local.common_vars.project_id}/regions/${local.common_vars.region}/subnetworks/divyam-${local.common_vars.environment}-subnet"
        cluster_ipv4_cidr        = "/21"        
        services_ipv4_cidr       = "/25"
        additional_pod_range_names = ["pods-extra", "pods"]
        enable_private_nodes     = true
        enable_private_endpoint  = false  #TODO: See if we need to set this to true later
        master_authorized_networks_cidr = [
          {
            cidr_block   = "0.0.0.0/0"
            display_name = "Allow all (dev)"
          }
        ]
        binauthz_evaluation_mode = "DISABLED"
        dns_scope                = "VPC_SCOPE"
        dns_domain               = "${local.derived_vars.k8s_cluster_name}"
        enable_workload_logs     = true
        enable_cluster_logs      = true
      }
    }
  }

  iam_bindings = {
    enabled = true    

    # Bind the provided service accounts to the required roles like artifact_registry reader, ci_cd deployer, metrics writer et.all
    ci_cd = {
      create_iam      = true      
      service_account = local.common_vars.ci_cd_service_account
      bucket_access = true
    }

    artifact_registry = {    
      create_iam     = true
      artifact_registry_project        = local.common_vars.ci_cd_artifact_registry_project
      artifact_registry_project_region = local.common_vars.ci_cd_artifact_registry_project_region      
      artifact_repositories   = local.common_vars.ci_cd_artifact_repositories
      service_account = "" # Can overwrite the default service account from where artifacts will be pulled
    }

    prometheus_metric_writer = {
      create_iam      = true      
      service_account = "" # Can overwrite the default service account which will be used to write metrics
    }
    
    # Add IAM policy binding to allow default node level google service account to impersonate the kubernetes service accounts
    # required for below changes to health, router controller, prometheus namespaces bindings
    default_node_service_account = {
      create_iam      = true
      service_account = "" # Can overwrite the default service account which is running on the GKE nodes
    }

    # Create new service account and Add IAM policy binding to allow google service account to 
    # impersonate the kubernetes service account for health, router controller namespaces
    kafka_connect = {
      create_sa       = true
      namespace       = "kafka-${local.common_vars.environment}-ns"
      service_account = "kafka-${local.common_vars.environment}-connect"
    }

    # Variables for billing
    billing = {
      create_sa       = true
      namespace       = "billing-${local.common_vars.environment}-ns"
      service_account = "billing-${local.common_vars.environment}-sa"
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
      bucket_name = "divyam-${local.common_vars.environment}-gcs-router-raw-logs"
    }

    secrets_accessor = {
      create_sa       = true
      service_account = "secrets-accessor-${local.common_vars.environment}-sa"
    }

    # For every Kubernetes SA that needs to be able to access secrets through External Secrets Operator,
    # Add the namespace, K8s SA names to the list
    ksa_bindings_for_secret_access = [
      # {namespace = "kaustav-test-ns", name = "secret-store-accessor-sa"}
      {namespace = "billing-${local.common_vars.environment}-ns", name = "billing-${local.common_vars.environment}-sa"}
    ]
  }

  cloud_build = {
    enabled         = false
    shared_vpc_name = "projects/${local.common_vars.project_id}/global/networks/divyam-${local.common_vars.environment}-shared-vpc-network"
  }

  alerts = {
    enabled        = local.common_vars.enable_notification_alerts
    exclude_list   = []
  }

  notification_channels = {
    enabled        = local.common_vars.enable_notification_alerts
    pager_enabled      = true
    pager_webhook_url  = local.common_vars.notification_pager_webhook_url
    gchat_enabled      = true
    gchat_space_id     = local.common_vars.notification_gchat_space_id
    email_enabled      = true
    email_alert_email  = local.common_vars.notification_email_alert_email
  }

  helm_charts = {
    enabled = true
    k8s_cluster_name = "${local.derived_vars.k8s_cluster_name}"
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
    values_file_path  = abspath("${get_parent_terragrunt_dir()}/../charts/setup/envs/${local.common_vars.environment}-values.yaml")
    chart_path        = abspath("${get_parent_terragrunt_dir()}/../charts/setup")
  }

  shared_vpc_service_project = {
    enabled = false
    host_project_id = local.common_vars.project_id
    # Need to give pre-prod environments or other project name which need access to shared vpc
    service_project_id = "${local.common_vars.project_id}-shared-project"  
  }


  # helm = {
  #   setup = {
  #     enabled      = true
  #     name         = "router-controller-preprod"
  #     namespace    = "router-controller-preprod"
  #     values_file  = "preprod-values.yaml"
  #   }
  # }
}
