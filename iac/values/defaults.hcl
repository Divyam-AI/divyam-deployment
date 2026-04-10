#-------------------------------------------------------------------------------------------------------------------------------
# Note: when setting in any of the section create = false, edit the values in that section that is to be used to setup Divyam.
#-------------------------------------------------------------------------------------------------------------------------------

locals {
  # Can replace these with actual values
  cloud_provider    = get_env("CLOUD_PROVIDER","azure") 
  env_name          = get_env("ENV","")
  org_name          = get_env("ORG_NAME", "")
  region            = get_env("REGION","centralindia")
  zone              = get_env("ZONE","centralindia-1")

  deployment_prefix = (
    length(local.org_name) > 0 ?
      "divyam-${local.org_name}-${local.env_name}" :
      "divyam-${local.env_name}"
  )

  # Can set key -> value for tags to be applied for cloud entities
  # GCP lables and values should contain lowercase letters, numeric characters, underscores, and dashes and cannot be longer than 63 characters each.
  common_tags       = {
    environment   = "divyam-env-#{environment}"
    resource_name = "#{resource_name}"
  } 
  # Can also use templates as value and will automatically replaced
  # Standard template variables are defined as part of tag_globals in root.hcl
  # { 
  #   environment     = "#{environment}"
  #   region          = "#{region}"
  #   resource_tag    = "#{org_name}-#{resource_name}"
  # }

#################### Foundation ##########################
# --- Resource Scope ---
# Azure: resource_group_name | GCP: project_id
  resource_scope = {
    create          = false   # If this is set to false, edit the name below to the resource name that is to be used for setting up Divyam.
    name            = "${local.deployment_prefix}-rg"
    # Get it from https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2 or https://console.cloud.google.com/billing/
    billing_account = get_env("BILLING_ACCOUNT", "") # BILLING_ACCOUNT is required if create is true
  }

# --- APIs / Resource Providers (0-foundation/0-apis) ---
# GCP: enable APIs; Azure: register resource providers. Set enabled = true; override apis (GCP) or provider_namespaces (Azure) here if needed.
  apis = {
    enabled = false
  }

# --- Virtual Network ---
  # Azure: VNet | GCP: VPC (optionally Shared VPC host with service project attachments)
  # When create = true (e.g. GCP): create network and subnets. When false: look up existing by name.
  # GCP: set shared_vpc_host = true to enable this project as Shared VPC host; set service_project_ids = ["project-a","project-b"] to attach service projects.
  vnet = {
    create          = false  # If this is set to false, edit the below values that is to be used for setting up Divyam.
    name            = "${local.deployment_prefix}-vnet"    
    scope_name      = "${local.resource_scope.name}" # Azure Resource Group or GCP Project where this vnet is to be created/present
    region          = "${local.region}"
    zone            = "${local.zone}"
    address_space   = ["10.0.0.0/16"]
    subnet          = { create = true, subnet_ip = "10.0.0.0/21", name = "${local.deployment_prefix}-subnet" } # (2048 IPs)
    app_gw_subnet   = { create = true, subnet_ip = "10.0.8.0/26", name = "${local.deployment_prefix}-subnet-app-gw" } # (64 IPs) - Required for Azure App Gateway or GCP proxy-only (min /26)
    # GCP only: enable Shared VPC host and attach service projects (ignored by Azure)
    # Azure: shared_vpc_host = true peers this VNet to remote VNets whose ARM IDs are in service_project_ids.
    shared_vpc_host     = false
    service_project_ids = []  # GCP: project IDs to attach; Azure: remote VNet ARM IDs to peer with
  }

  # --- NAT (egress) ---
  # Azure: NAT Gateway + Public IP, associated to VNet subnets. GCP: Cloud NAT on Cloud Router for listed subnetworks.
  # Lookup names: platform modules fetch nat_gateway_ip via data sources (Azure: public IP by name; GCP: router/nat by name). Names must match 0-foundation/2-nat or existing infra.
  nat = {
    create = false # If this is set to false, edit the below values that is to be used for setting up Divyam.
    resource_name_prefix = "${local.deployment_prefix}"
    # Names for data-source lookup (1-platform resolves NAT IP from these; no dependency on 0-foundation).
    nat_gateway_name   = "${local.deployment_prefix}-nat-gateway"   # Azure: NAT gateway resource name
    nat_public_ip_name = "${local.deployment_prefix}-nat-ip"       # Azure: public IP resource name (used to fetch IP)    
    # GCP: Cloud Router and NAT config names (for lookup if needed)
    router_name     = "${local.deployment_prefix}-nat-router"
    nat_config_name = "${local.deployment_prefix}-nat-config"
  }

  # --- Bastion ---
  # Set create = true and override below. Cluster details for kubectl come from k8s section (no cloud-specific names).
  bastion = {
    create       = false # If this is set to false, edit the below values that is to be used for setting up Divyam.
    bastion_name = "${local.deployment_prefix}-bastion"
    spot_instance = false
    # configure_kubectl: use only when cluster is pre-created and only the bastion needs to be set up (installs kubectl + setup-kubectl script on bastion at create time).
    # Once the cluster is created (1-platform), either run on the bastion: setup-kubectl, or set k8s.setup_kubectl_on_bastion = true to run it via Terraform.
    # Azure: vnet_subnet_name, vm_size, admin_username, ssh_public_key_path. GCP: machine_type, tags.
    vm_size = "Standard_B2s"
  }

# --- Blob / Object Storage ---
# Azure: Resource Group -> Storage Account -> Container | GCP: Project -> GCS bucket(s)
  # --- Terraform State Backend ---
  # bucket_name: cloud-agnostic logical name for state store (Azure: container + storage account; GCP: bucket).
  # Override here if needed (e.g. storage_account_name, container_name for Azure).
  # local_state: when true, state is stored locally only (no cloud bucket/container created or used).
  tfstate = {
    create         = false # If this is set to false, edit the below values that is to be used for setting up Divyam.
    local_state    = true
    region         = "${local.region}"
    zone           = "${local.zone}"
    scope_name     = "${local.resource_scope}"                              # Azure Resource Group or GCP Project
    storage_name   = "storage"                                              # Azure Storage Account or GCP - empty
    bucket_name    = "${replace(local.deployment_prefix, "-", "")}tfstate" # Azure container + storage account name; GCP bucket name
  }

#################### Platform ##########################
  # --- Divyam Data ---
  divyam_object_storages = [{
    create               = true # If this is set to false, edit the below values that is to be used for setting up Divyam.
    type                 = "router-requests-logs"                                  # Identifies this storage for router-requests-logs
    scope_name           = "${local.resource_scope}"                               # Azure Resource Group or GCP Project
    storage_account_name = "${replace(local.deployment_prefix, "-", "")}storage"   # Full Azure storage account name (no dashes). Not for GCP; used for grouping
    container_name       = "${replace(local.deployment_prefix, "-", "")}container" # Azure Container or GCP Bucket
  }]

  # -- Secrets ---
  divyam_secrets = {
    # If this is set to false, edit the below values that is to be used for setting up Divyam.
    create_vault   = true   # Azure only: if false, use store_name to look up existing Key Vault
    create_secrets = true   # if false, do not create or update secrets in the vault
    scope_name     = "${local.resource_scope.name}"       # Azure Resource Group or GCP Project
    store_name     = "${local.deployment_prefix}-vault"   # Azure Key Vault name (create or lookup).  Not required for GCP
  }

  # -- Load Balancer (static IP, DNS, TLS) ---
  divyam_load_balancer = {
    enabled = true
    create_ip = true # If this is set to false, edit the below values that is to be used for setting up Divyam.
    # Private IP (internal LB only): address and optional resource name.
    ip               = "10.0.8.10"  # Reserved private IP in VNET app_gw_subnet (ignored when public = true)
    private_ip_name  = "${local.deployment_prefix}-private-ip"  # Name for the private IP resource (e.g. GCP internal address)

    public = false
    create_public_ip = true  # When true and public = true, create new public IP; when false, use existing by public_ip_name    
    public_ip_name  = "${local.deployment_prefix}-ip"  # Name for new public IP, or name of existing if create_public_ip = false

    service_name         = "${local.deployment_prefix}-service"
    backend_service_name = "${local.deployment_prefix}-service-backend"

    tls_enabled     = false
    create_ssl_cert = false  # Used only if tls_enabled is true. When false, use external cert (certificate_secret_id).
    ssl_cert_name   = "${local.deployment_prefix}-lb-ssl-cert"

    # DNS names for TLS SANs and for DNS A records (IP mapping: these names resolve to LB IP — public when public=true, private when false).
    create_dns_records = true  # When true, create Private DNS A records mapping router_dns/dashboard_dns to LB IP.
    router_dns = (local.org_name != "" ?
      "api.${local.env_name}.${local.org_name}.divyam.local" :
      "api.${local.env_name}.divyam.local")
    dashboard_dns = (local.org_name != "" ?
      "dashboard.${local.env_name}.${local.org_name}.divyam.local" :
      "dashboard.${local.env_name}.divyam.local")
    # Optional toggle: set empty string ("") to disable controlplane DNS creation/export and use deployment_mode = "onprem".
    controlplane_dns = (local.org_name != "" ?
      "controlplane.${local.env_name}.${local.org_name}.divyam.local" :
      "controlplane.${local.env_name}.divyam.local")

    waf_enabled = true
    create_waf  = true   # When true, create WAF/Cloud Armor policy in-module; when false and waf_enabled, fetch existing by waf_policy_name and attach
    waf_policy_name = "${local.deployment_prefix}-waf"  # Name for created policy or name of existing to fetch when create_waf = false

    # WAF deny/allow lists (applied when create_waf = true). Empty = no rule.
    waf_deny_ip_ranges  = []  # IP/CIDR to block (e.g. ["203.0.113.0/24"])
    waf_allow_ip_ranges = []  # If non-empty: only these IP/CIDR allowed (allowlist); still apply deny list first
  }

  # --- Azure Application Gateway Ingress Controller (AGIC) ---
  agic = {
    enabled            = true
    helm_chart_version = "1.8.1"
    namespace          = "kube-system"
    # Defaults to "<k8s.name>-ingress-azure" when null.
    release_name       = null
    verbosity_level    = 3
  }

  # --- Kubernetes Cluster ---
  # Cloud-agnostic schema; 1-platform/1-k8s/<cloud> maps from k8s. Region, vnet names come from root (not duplicated here).
  k8s = {
    create = true # If this is set to false, edit the below values that is to be used for setting up Divyam.
    name   = "${local.deployment_prefix}-k8s-cluster"
    kubernetes_version = "1.34"

    # Use spot/preemptible nodes per pool (GKE: spot; AKS: priority Spot). Set spot_instance = true on each pool that should use spot.
    # "Auto" = platform-managed nodes (Azure NAP, GKE Autopilot). "Manual" = explicit node pools / VM size.
    node_provisioning_mode = "Auto" #"Manual"

    api_server_authorized_ip_ranges = []

    node_pools = {
      default = {
        instance_type = local.cloud_provider == "azure" ? "Standard_D4s_v3" : "e2-standard-4"
        spot_instance = false           # system agent should not be spot
        auto_scaling  = false
        count        = 1
      }
      additional = {}
    }

    observability = {
      enable_logs         = true
      # Maximum retention: GCP _Default bucket = 3650 days; Azure Log Analytics = 730 days (capped in 1-k8s).
      logs_retention_days = 30
      enable_metrics      = true
    }

    # Upgrade cadence: Azure = automatic_channel_upgrade (stable|rapid|patch|node-image), GCP = release_channel (REGULAR|RAPID|STABLE). Set per cloud.
    release_channel = local.cloud_provider == "azure" ? "stable" : "REGULAR"

    # When true, enables 1-platform/2-bastion-kubectl-setup (run setup-kubectl on bastion after cluster exists). Bastion must have been created with bastion.configure_kubectl so the script exists.
    setup_kubectl_on_bastion = false
  }

  # --- Datadog ---
  # When enabled:
  # - set registry to your Datadog site (for example: datadoghq.com, datadoghq.eu, ap1.datadoghq.com)
  # - set env to the deployment environment tag to be sent to Datadog
  # - export TF_VAR_datadog_api_key before running terragrunt
  datadog = {
    enabled  = false
    registry = ""
    env      = ""
  }

  iam_bindings = {
    create = true
  }

  alerts = {
    create         = true
    enabled        = true
    exclude_list   = []

    notification_channels = {
      pager_enabled      = true
      pager_webhook_url  = get_env("NOTIFICATION_PAGER_WEBHOOK_URL", "")
      gchat_enabled      = true
      gchat_space_id     = get_env("NOTIFICATION_GCHAT_SPACE_ID", "")
      email_enabled      = true
      email_alert_email  = get_env("NOTIFICATION_EMAIL_ALERT_EMAIL", "")
      slack_enabled      = true
      slack_webhook_url  = get_env("NOTIFICATION_SLACK_WEBHOOK_URL", "")
    }
  }

#################### Application ##########################

  # --- Export Details (provider.yaml for Helm) ---
  # Generates k8s/values/provider.yaml consumed by helmfile. Cloud-specific values (Key Vault URI, WIF, GCS bucket)
  # are pulled from other module outputs automatically; only shared settings need to be configured here.
  # When cloudsql.create = true, database connection details are also included.
  export_details = {
    cluster_domain            = ""
    image_pull_secret_enabled = local.cloud_provider == "azure" ? true : false
    output_dir                = "k8s/helm-values"
  }

  # If not create, can setup mysql inside K8s. Default is inside K8s
  cloudsql = {
    create         = false
    instance_name  = "${local.deployment_prefix}-cloudsql"
  }

  # --- Terraform outputs file for Helm ---
  # Path (relative to repo root) with filename and extension. Use .yaml or .json for format.
  # Dynamic placeholders (resolved from ENV/ORG_NAME when the script runs): ${local.deployment_prefix}, ${local.env_name}, ${local.org_name}
  outputs_file_path = "outputs/outputs-${local.deployment_prefix}.yaml"
}