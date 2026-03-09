#----------------------------------------------
# Cloud-agnostic deployment configuration.
# These values feed into both Azure and GCP. Cloud-specific provider/backend are in root.hcl.
#
# When create = false, use existing resources; provide the names below for lookup.
#----------------------------------------------

locals {
  # Can replace these with actual values
  cloud_provider    = get_env("CLOUD_PROVIDER") 
  env_name          = get_env("ENV")
  org_name          = get_env("ORG_NAME")
  region            = get_env("REGION")
  zone              = get_env("ZONE")

  deployment_prefix = (
    length(local.org_name) > 0 ?
      "divyam-${local.org_name}-${local.env_name}" :
      "divyam-${local.env_name}"
  )

  # Can set key -> value for tags to be applied for cloud entities
  common_tags       = {
    Environment   = "#{environment}"
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
    create  = false
    # TODO: Remove these temp values
    #name    = "${local.deployment_prefix}-rg"
    name    = local.cloud_provider == "azure" ? "rg-sudhir-4084" : "sudhir-workspace" # Azure | GCP
  }

# --- APIs / Resource Providers (0-foundation/1-apis) ---
# GCP: enable APIs; Azure: register resource providers. Set enabled = true; override apis (GCP) or provider_namespaces (Azure) here if needed.
  apis = {
    enabled = true
  }

# --- Virtual Network ---
  # Azure: VNet | GCP: VPC (optionally Shared VPC host with service project attachments)
  # When create = true (e.g. GCP): create network and subnets. When false: look up existing by name.
  # GCP: set shared_vpc_host = true to enable this project as Shared VPC host; set service_project_ids = ["project-a","project-b"] to attach service projects.
  vnet = {
    create          = false
    # TODO: Remove these temp values
    #name            = "${local.deployment_prefix}-vnet"
    name            = local.cloud_provider == "azure" ? "rg-sudhir-4084-vnet" : "default" # Azure | GCP
    scope_name      = "${local.resource_scope.name}" # Azure Resource Group or GCP Project where this vnet is to be created/present
    region          = "${local.region}"
    zone            = "${local.zone}"
    address_space   = ["10.0.0.0/16"]
    # TODO: Remove these temp values
    subnet          = { create = false, subnet_ip = "10.0.0.0/21", name = local.cloud_provider == "azure" ? "rg-sudhir-4084-subnet" : "default"  } # "${local.deployment_prefix}-subnet" (2048 IPs)
    app_gw_subnet   = { create = false, subnet_ip = "10.0.8.0/27", name = local.cloud_provider == "azure" ? "rg-sudhir-4084-app-gw-subnet" : "default-app-gw-subnet" } # "${local.deployment_prefix}-subnet-app-gw" (32 IPs)  - Required for Azure App Gateway or GCP Proxy
    # GCP only: enable Shared VPC host and attach service projects (ignored by Azure)
    # Azure: shared_vpc_host = true peers this VNet to remote VNets whose ARM IDs are in service_project_ids.
    shared_vpc_host     = false
    service_project_ids = []  # GCP: project IDs to attach; Azure: remote VNet ARM IDs to peer with
  }

  # --- NAT (egress) ---
  # Azure: NAT Gateway + Public IP, associated to VNet subnets. GCP: Cloud NAT on Cloud Router for listed subnetworks.
  # Lookup names: platform modules fetch nat_gateway_ip via data sources (Azure: public IP by name; GCP: router/nat by name). Names must match 0-foundation/2-nat or existing infra.
  nat = {
    create = true
    resource_name_prefix = "${local.deployment_prefix}"
    # Names for data-source lookup (1-platform resolves NAT IP from these; no dependency on 0-foundation).
    nat_gateway_name   = "${local.deployment_prefix}-nat-gateway"   # Azure: NAT gateway resource name
    #TODO: Remove these temp values
    # nat_public_ip_name = "${local.deployment_prefix}-nat-ip"       # Azure: public IP resource name (used to fetch IP)
    nat_public_ip_name = "${local.deployment_prefix}-nat-ip-4084"       # Azure: public IP resource name (used to fetch IP)
    # GCP: Cloud Router and NAT config names (for lookup if needed)
    router_name     = "${local.deployment_prefix}-nat-router"
    nat_config_name = "${local.deployment_prefix}-nat-config"
  }

  # --- Bastion ---
  # Azure: Linux VM with public IP, NSG (SSH). GCP: Compute instance with firewall (SSH).
  # Set create = true and override below. Cluster details for kubectl come from k8s section (no cloud-specific names).
  bastion = {
    create       = false
    bastion_name = "${local.deployment_prefix}-bastion"
    # configure_kubectl: use only when cluster is pre-created and only the bastion needs to be set up (installs kubectl + setup-kubectl script on bastion at create time).
    # Once the cluster is created (1-platform), either run on the bastion: setup-kubectl, or set k8s.setup_kubectl_on_bastion = true to run it via Terraform.
    # Azure: vnet_subnet_name, vm_size, admin_username, ssh_public_key_path. GCP: machine_type, tags.
  }

# --- Blob / Object Storage ---
# Azure: Resource Group -> Storage Account -> Container | GCP: Project -> GCS bucket(s)
  # --- Terraform State Backend ---
  # bucket_name: cloud-agnostic logical name for state store (Azure: container + storage account; GCP: bucket).
  # Override here if needed (e.g. storage_account_name, container_name for Azure).
  tfstate = {
    create         = true
    region         = "${local.region}"
    zone           = "${local.zone}"
    scope_name     = "${local.resource_scope}"                              # Azure Resource Group or GCP Project
    storage_name   = "storage"                                              # Azure Storage Account or GCP - empty
    bucket_name    = "${replace(local.deployment_prefix, "-", "")}tfstate" # Azure container + storage account name; GCP bucket name
  }

#################### Platform ##########################
  # --- Divyam Data ---
  divyam_object_storages = [{
    create               = true
    type                 = "router-requests-logs"                                  # Identifies this storage for router-requests-logs
    scope_name           = "${local.resource_scope}"                               # Azure Resource Group or GCP Project
    storage_account_name = "${replace(local.deployment_prefix, "-", "")}storage"   # Full Azure storage account name (no dashes). Not for GCP; used for grouping
    container_name       = "${replace(local.deployment_prefix, "-", "")}container" # Azure Container or GCP Bucket
  }]

  # -- Secrets ---
  divyam_secrets = {
    create_vault   = true   # Azure only: if false, use store_name to look up existing Key Vault
    create_secrets = true   # if false, do not create or update secrets in the vault
    scope_name     = "${local.resource_scope.name}"       # Azure Resource Group or GCP Project
    # TODO: Change the defaults
    # store_name     = "${local.deployment_prefix}-vault"   # Azure Key Vault name (create or lookup)
    store_name     = local.cloud_provider == "azure" ? "divyam-dev-vault-4048" : "${local.deployment_prefix}-vault"   # Azure Key Vault name (create or lookup). Not required for GCP
    
  }

  # -- Load Balancer (static IP, DNS, TLS) ---
  divyam_load_balancer = {
    create_ip = true
    # Private IP (internal LB only): address and optional resource name.
    ip               = "10.0.8.10"  # Reserved private IP in VNET app_gw_subnet (ignored when public = true)
    private_ip_name  = "${local.deployment_prefix}-private-ip"  # Name for the private IP resource (e.g. GCP internal address)

    public = false
    create_public_ip = true  # When true and public = true, create new public IP; when false, use existing by public_ip_name    
    public_ip_name  = "${local.deployment_prefix}-ip"  # Name for new public IP, or name of existing if create_public_ip = false

    service_name         = "${local.deployment_prefix}-service"
    backend_service_name = "${local.deployment_prefix}-service-backend"

    tls_enabled     = true
    create_ssl_cert = true  # Used only if tls_enabled is true. When false, use external cert (certificate_secret_id).
    ssl_cert_name   = "${local.deployment_prefix}-lb-ssl-cert"

    # DNS names for TLS SANs and for DNS A records (IP mapping: these names resolve to LB IP — public when public=true, private when false).
    create_dns_records = true  # When true, create Private DNS A records mapping router_dns/dashboard_dns to LB IP.
    router_dns = (local.org_name != "" ?
      "api.${local.env_name}.${local.org_name}.divyam.local" :
      "api.${local.env_name}.divyam.local")
    dashboard_dns = (local.org_name != "" ?
      "dashboard.${local.env_name}.${local.org_name}.divyam.local" :
      "dashboard.${local.env_name}.divyam.local")

    waf_enabled = true
    create_waf  = true   # When true, create WAF/Cloud Armor policy in-module; when false and waf_enabled, fetch existing by waf_policy_name and attach
    waf_policy_name = "${local.deployment_prefix}-waf"  # Name for created policy or name of existing to fetch when create_waf = false

    # WAF deny/allow lists (applied when create_waf = true). Empty = no rule.
    waf_deny_ip_ranges  = []  # IP/CIDR to block (e.g. ["203.0.113.0/24"])
    waf_allow_ip_ranges = []  # If non-empty: only these IP/CIDR allowed (allowlist); still apply deny list first
  }

  # --- Kubernetes Cluster ---
  # Cloud-agnostic schema; 1-platform/1-k8s/<cloud> maps from k8s. Region, vnet names come from root (not duplicated here).
  k8s = {
    create = true
    name   = "${local.deployment_prefix}-k8s-cluster"
    kubernetes_version = "1.28"

    # "Auto" = platform-managed nodes (Azure NAP, GKE Autopilot). "Manual" = explicit node pools / VM size.
    node_provisioning_mode = "Auto" #"Manual"

    api_server_authorized_ip_ranges = []

    node_pools = {
      default = {
        instance_type = local.cloud_provider == "azure" ? "Standard_D4s_v3" : "e2-standard-4"
        auto_scaling  = true
        min_count    = 1
        max_count    = 5
        count        = null
      }
      additional = {
        gpupool = {
          instance_type = local.cloud_provider == "azure" ? "Standard_NV6ads_A10_v5" : "n1-standard-4"
          count         = 2
          auto_scaling = false
          min_count    = null
          max_count    = null
          node_taints  = ["sku=gpu:NoSchedule"]
          node_labels  = { gpu = "true" }
        }
      }
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

  # If not create, can setup mysql inside K8s. Default is inside K8s
  cloudsql = {
    create         = false
    instance_name  = "${local.deployment_prefix}-cloudsql"
  }

# --- Terraform outputs file for Helm ---
  # Path with extension; supports ${local.deployment_prefix}, ${local.env_name}, ${local.org_name} (resolved from ENV/ORG_NAME)
  outputs_file_path = "outputs/outputs-${local.deployment_prefix}.yaml"
}