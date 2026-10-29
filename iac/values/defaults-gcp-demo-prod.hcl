#-------------------------------------------------------------------------------------------------------------------------------
# Note: when setting in any of the section create = false, edit the values in that section that is to be used to setup Divyam.
#-------------------------------------------------------------------------------------------------------------------------------
# PROFILE: GCP demo prod (project divyam-demo, region asia-south1), built from scratch: every unit
# creates its resources. Runs the router, evalm8 (eval-only) and self-serve stacks; only the switch
# is exposed publicly.
# The Terragrunt state path embeds this file's basename, so renaming it forks the state.
#-------------------------------------------------------------------------------------------------------------------------------

locals {
  # Can replace these with actual values
  cloud_provider = get_env("CLOUD_PROVIDER", "gcp")
  env_name       = get_env("ENV", "prod")
  org_name       = get_env("ORG_NAME", "demo")
  region         = get_env("REGION", "asia-south1")
  zone           = get_env("ZONE", "asia-south1-a")

  # Stack selector: which Divyam stack this deployment provisions and deploys.
  # A comma-separated list of "router", "evalm8", "self-serve" — or "all" (the default).
  # 3-export_details writes this into provider.yaml (like deployment_mode), so the helmfile deploys the same stack this infra was provisioned for.
  # It also gates the evalm8-only cloud resources (the new charts' secret-manager keys and the lakeFS object storage) so a router-only deployment does not provision them.
  # self-serve needs the router controller in-cluster. evalm8 runs eval-only: its lakeFS store is
  # provisioned, while Temporal and Argilla are switched off in the Helm values.
  stack = get_env("STACK", "router,evalm8,self-serve")
  # Whether evalm8 is in the stack list. Membership, not inequality: a list can exclude evalm8
  # without equalling "router".
  evalm8_in_stack = local.stack == "all" || contains([for s in split(",", local.stack) : trimspace(s)], "evalm8")
  # Whether self-serve is in the stack list. Gates the switch object storage, the managed Postgres
  # (Cloud SQL) and the self-serve secrets the same way evalm8_in_stack gates lakeFS, so a
  # router-only deployment provisions none of them.
  self_serve_in_stack = local.stack == "all" || contains([for s in split(",", local.stack) : trimspace(s)], "self-serve")

  deployment_mode = "onprem" # Set value to "managed" | "onprem"

  deployment_prefix = (
    length(local.org_name) > 0 ?
    "divyam-${local.org_name}-${local.env_name}" :
    "divyam-${local.env_name}"
  )

  # Can set key -> value for tags to be applied for cloud entities
  # GCP lables and values should contain lowercase letters, numeric characters, underscores, and dashes and cannot be longer than 63 characters each.
  common_tags = {
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
    create = false # If this is set to false, edit the name below to the resource name that is to be used for setting up Divyam.
    name   = "divyam-demo"
    # Get it from https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2 or https://console.cloud.google.com/billing/
    # Empty: the project and its billing link are managed outside Terraform. A value here is linked even with create = false.
    billing_account = get_env("BILLING_ACCOUNT", "")
  }

  # --- APIs / Resource Providers (0-foundation/0-apis) ---
  # GCP: enable APIs; Azure: register resource providers. Set enabled = true; override apis (GCP) or provider_namespaces (Azure) here if needed.
  apis = {
    enabled = true
    apis = [
      "compute.googleapis.com",
      "container.googleapis.com",
      "iam.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "storage.googleapis.com",
      "logging.googleapis.com",
      "monitoring.googleapis.com",
      "secretmanager.googleapis.com",
      "dns.googleapis.com",
      "networkmanagement.googleapis.com",
      "servicenetworking.googleapis.com",
      "sqladmin.googleapis.com", # Cloud SQL (MySQL and self-serve Postgres)
    ]
  }

  # --- Virtual Network ---
  # Azure: VNet | GCP: VPC (optionally Shared VPC host with service project attachments)
  # When create = true (e.g. GCP): create network and subnets. When false: look up existing by name.
  # GCP: set shared_vpc_host = true to enable this project as Shared VPC host; set service_project_ids = ["project-a","project-b"] to attach service projects.
  vnet = {
    create = true
    name   = "${local.deployment_prefix}-vnet"
    scope_name = "${local.resource_scope.name}" # Azure Resource Group or GCP Project where this vnet is to be created/present
    region        = "${local.region}"
    zone          = "${local.zone}"
    # Kept clear of divyam-production (10.148.0.0/20, 10.180.0.0) so the two VPCs can be peered later.
    address_space = ["10.20.0.0/16"]
    subnet        = { create = true, subnet_ip = "10.20.0.0/21", name = "${local.deployment_prefix}-subnet" }         # (2048 IPs)
    app_gw_subnet = { create = true, subnet_ip = "10.20.8.0/26", name = "${local.deployment_prefix}-subnet-app-gw" } # (64 IPs) GCP proxy-only; the vnet unit requires it
    # GCP only: enable Shared VPC host and attach service projects (ignored by Azure)
    # Azure: shared_vpc_host = true peers this VNet to remote VNets whose ARM IDs are in service_project_ids.
    shared_vpc_host     = false
    service_project_ids = [] # GCP: project IDs to attach; Azure: remote VNet ARM IDs to peer with
    # Cloud SQL private IP peering, owned here so MySQL and Postgres both depend only on the network.
    private_service_access = { create = true }
  }

  # --- NAT (egress) ---
  # Azure: NAT Gateway + Public IP, associated to VNet subnets. GCP: Cloud NAT on Cloud Router for listed subnetworks.
  # Lookup names: platform modules fetch nat_gateway_ip via data sources (Azure: public IP by name; GCP: router/nat by name). Names must match 0-foundation/2-nat or existing infra.
  nat = {
    create = true
    # Azure: resource group where the existing NAT gateway and public IP live (only used when create = false).
    # Leave unset or null to fall back to resource_scope.name.
    # Names for data-source lookup (1-platform resolves NAT IP from these; no dependency on 0-foundation).
    nat_gateway_name   = "${local.deployment_prefix}-nat-gateway" # Azure: NAT gateway resource name
    nat_public_ip_name = "${local.deployment_prefix}-nat-ip"      # Azure: public IP resource name (used to fetch IP)
    # GCP: Cloud Router and NAT config names (for lookup if needed)
    router_name     = "${local.deployment_prefix}-nat-router"
    nat_config_name = "${local.deployment_prefix}-nat-config"
  }

  # --- Bastion ---
  # Set create = true and override below. Cluster details for kubectl come from k8s section (no cloud-specific names).
  bastion = {
    create       = false
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
    create       = true
    local_state  = false
    region       = "${local.region}"
    zone         = "${local.zone}"
    scope_name   = "${local.resource_scope.name}"                          # Azure Resource Group or GCP Project
    storage_name = ""                                                      # Azure Storage Account or GCP - empty
    bucket_name  = "${local.resource_scope.name}-terraform-state-bucket" # Azure container + storage account name; GCP bucket name
  }

  #################### Platform ##########################
  # --- Divyam Data ---
  divyam_object_storages = [{
    create               = true
    type                 = "router-requests-logs"                                # Identifies this storage for router-requests-logs
    scope_name           = "${local.resource_scope}"                             # Azure Resource Group or GCP Project
    storage_account_name = "${replace(local.deployment_prefix, "-", "")}storage" # Full Azure storage account name (no dashes). Not for GCP; used for grouping
    container_name       = "${local.deployment_prefix}-gcs-router-raw-logs"
  }]

  # --- Evalm8 Data (lakeFS object storage) ---
  # Only provisioned when evalm8 is in the stack list. Empty otherwise.
  # Mirrors the divyam_object_storages element shape. type = "lakefs-data" identifies the lakeFS data store.
  # storage_account_name groups this into its own Azure storage account, kept distinct from the router account.
  # On GCP storage_account_name is only a grouping key, container_name is the GCS bucket name.
  evalm8_object_storages = local.evalm8_in_stack ? [{
    create               = true                                                 # If this is set to false, edit the below values that is to be used for setting up Divyam.
    type                 = "lakefs-data"                                        # Identifies this storage as the lakeFS data store
    scope_name           = "${local.resource_scope}"                            # Azure Resource Group or GCP Project
    storage_account_name = "${replace(local.deployment_prefix, "-", "")}lakefs" # Full Azure storage account name (no dashes). Not for GCP, used for grouping
    container_name       = "${replace(local.deployment_prefix, "-", "")}lakefs" # GCP bucket name and Azure container name for the lakeFS data store
  }] : []

  # --- Switch Data (selector bundle object storage) ---
  # Only provisioned when self-serve is in the stack list. Empty otherwise.
  # Mirrors the divyam_object_storages element shape. type = "selectors" identifies the bundle store.
  # The switch reads selector zips and eval definitions from here at startup and never writes, so the
  # service account gets objectViewer and nothing more.
  self_serve_object_storages = local.self_serve_in_stack ? [{
    create               = true # No training pipeline publishes to this env yet; starts empty.
    type                 = "selectors"                                              # Identifies this storage as the selector bundle store
    scope_name           = "${local.resource_scope}"                                # Azure Resource Group or GCP Project
    storage_account_name = "${replace(local.deployment_prefix, "-", "")}selectors"  # Azure storage account name. On GCP only a grouping key
    container_name       = "${local.deployment_prefix}-selectors"                   # GCS bucket name holding the published selector bundles
  }] : []

  # -- Secrets ---
  divyam_secrets = {
    # If this is set to false, edit the below values that is to be used for setting up Divyam.
    create_vault   = false                              # Azure only: if false, use store_name to look up existing Key Vault
    create_secrets = true                               # if false, do not create or update secrets in the vault
    scope_name     = "${local.resource_scope.name}"     # Azure Resource Group or GCP Project
    store_name     = "${local.deployment_prefix}-vault" # Azure Key Vault name (create or lookup).  Not required for GCP
  }

  # -- Load Balancer (static IP, DNS, TLS) ---
  # Off: public traffic enters through the GKE Ingress of self-serve-ingress, fed by ingress_inputs.
  divyam_load_balancer = {
    enabled   = false
    create_ip = true # If this is set to false, edit the below values that is to be used for setting up Divyam.
    # Private IP (internal LB only): address and optional resource name.
    private_ip_name = "${local.deployment_prefix}-private-ip" # Name for the private IP resource (e.g. GCP internal address)

    public           = false
    create_public_ip = false                           # When true and public = true, create new public IP; when false, use existing by public_ip_name    
    public_ip_name   = "${local.deployment_prefix}-ip" # Name for new public IP, or name of existing if create_public_ip = false

    service_name         = "${local.deployment_prefix}-service"
    backend_service_name = "${local.deployment_prefix}-service-backend"

    tls_enabled     = false
    create_ssl_cert = false # Used only if tls_enabled is true. When false, use external cert (certificate_secret_id).
    ssl_cert_name   = "${local.deployment_prefix}-lb-ssl-cert"

    # DNS records in a single private zone (all names resolve to LB IP — public when public=true, private when false).
    create_dns_records = true
    private_dns_zone = {
      # Set create=false to use an already-existing private DNS zone with this name.
      create = true
      name   = "${local.env_name}.divyam.local"
    }
    dns_records = {
      # Relative labels inside private_dns_zone.name (final FQDN = "<label>.<zone>").
      api       = "api"
      dashboard = "dashboard"
      # controlplane must be non-empty when deployment_mode = "managed".
      controlplane = "control"
    }
    # Additional VNets that should resolve this private DNS zone.
    # Example: [{ name = "shared-vnet", resource_group_name = "network-rg" }]
    dns_additional_calling_vnets = []

    # Options: "Standard_v2" (no WAF, lower cost) or "WAF_v2" (WAF enabled, current default).
    gateway_sku = "Standard_v2"

    waf_enabled     = false
    create_waf      = false                            # When true, create WAF/Cloud Armor policy in-module; when false and waf_enabled, fetch existing by waf_policy_name and attach
    waf_policy_name = "${local.deployment_prefix}-waf" # Name for created policy or name of existing to fetch when create_waf = false

    # WAF deny/allow lists (applied when create_waf = true). Empty = no rule.
    waf_deny_ip_ranges  = [] # IP/CIDR to block (e.g. ["203.0.113.0/24"])
    waf_allow_ip_ranges = [] # If non-empty: only these IP/CIDR allowed (allowlist); still apply deny list first
  }

  # --- Azure Application Gateway Ingress Controller (AGIC) ---
  agic = {
    enabled            = false
    helm_chart_version = "1.8.1"
    namespace          = "kube-system"
    # Defaults to "<k8s.name>-ingress-azure" when null.
    release_name    = null
    verbosity_level = 3
  }

  # --- Kubernetes Cluster ---
  # Cloud-agnostic schema; 1-platform/1-k8s/<cloud> maps from k8s. Region, vnet names come from root (not duplicated here).
  k8s = {
    create             = true # If this is set to false, edit the below values that is to be used for setting up Divyam.
    name               = "${local.deployment_prefix}-k8s-cluster"
    kubernetes_version = "1.34"

    # Use spot/preemptible nodes per pool (GKE: spot; AKS: priority Spot). Set spot_instance = true on each pool that should use spot.
    # "Auto" = platform-managed nodes (Azure NAP, GKE Autopilot). "Manual" = explicit node pools / VM size.
    node_provisioning_mode = "Manual" # GCP: Standard cluster, pools declared below
    location               = local.zone

    enable_private_endpoint  = false
    enable_cost_allocation   = true
    remove_default_node_pool = true
    deletion_protection      = true

    # Optional AKS network ranges. Keep them non-overlapping with VNet/subnets.
    # VNet: 10.0.0.0/16 | AKS subnet: 10.0.0.0/21 | App GW subnet: 10.0.8.0/26
    service_cidr   = "170.20.0.0/16"
    dns_service_ip = "170.20.0.10"
    pod_cidr       = null

    api_server_authorized_ip_ranges = []

    # NAP NodePool instance families/sizes (list). Override per environment as needed.
    # cpu_instance_types = null
    # gpu_instance_types = null

    node_pools = {
      additional = {
        spot = {
          instance_type = "e2-standard-4"
          spot_instance = true
          auto_scaling  = false
          count         = 6
        }
      }
    }

    observability = {
      enable_logs = true
      # Maximum retention: GCP _Default bucket = 3650 days; Azure Log Analytics = 730 days (capped in 1-k8s / 2-monitoring).
      logs_retention_days = 30
      enable_metrics      = true
    }

    # Upgrade cadence: Azure = automatic_channel_upgrade (stable|rapid|patch|node-image), GCP = release_channel (REGULAR|RAPID|STABLE). Set per cloud.
    release_channel = local.cloud_provider == "azure" ? "stable" : "REGULAR"

    # When true, enables 1-platform/3-bastion-kubectl-setup (run setup-kubectl on bastion after cluster exists). Bastion must have been created with bastion.configure_kubectl so the script exists.
    setup_kubectl_on_bastion = false
  }

  # --- Platform monitoring (1-platform/2-monitoring) ---
  monitoring = {
    create   = true
    provider = "cloud_native"

    native = {
      enable_logs               = true
      enable_metrics            = true
      logs_retention_days       = 30
      manage_project_log_bucket = true

      create_amw                   = true
      azure_monitor_workspace_name = null
      azure_monitor_workspace_id   = null
      grafana_endpoint             = null

      gcp_project_id       = null
      gmp_cluster_name     = null
      gmp_cluster_location = null # zone or region of gmp_cluster_name; null uses k8s.location
    }
  }

  # --- Datadog (optional; 1-platform/2-monitoring/datadog when enabled) ---
  # When enabled:
  # - set registry to your Datadog site (for example: datadoghq.com, datadoghq.eu, ap1.datadoghq.com)
  # - set env to the deployment environment tag to be sent to Datadog
  # - export TF_VAR_datadog_api_key before running terragrunt
  # - exclude_namespaces is always applied to both logs and metrics.
  # - exclude_namespaces_logs and exclude_namespaces_metrics are additive granular lists
  #   appended to the shared exclude_namespaces list.
  datadog = {
    enabled  = false
    site     = "ap1.datadoghq.com"
    registry = "asia.gcr.io/datadoghq"
    env      = local.env_name # Datadog Agent env tag only (2-monitoring/datadog). Monitors use env_name via monitor_env.
    # monitor_env = null  # optional override for monitor env: tag; default = env_name (e.g. prod)
    # custom_cluster_name = null  # when k8s.create = false; must match {{cluster_name}} in 2-alerts rules
    exclude_namespaces = [
      "default",
      "kube-system",
    ]
    exclude_namespaces_logs    = []
    exclude_namespaces_metrics = []
  }

  iam_bindings = {
    create = true
  }

  alerts = {
    create       = false
    enabled      = false
    exclude_list = []

    # Pager / Zenduty-style webhook URLs. Every CRITICAL alert fires to every URL in
    # this list. The list is the only notification config — there is no per-channel
    # routing. Empty strings are filtered out by the modules.
    # Provide as a single comma-separated env var (NOTIFICATION_WEBHOOK_URLS) or
    # populate individual entries from env.
    webhook_urls = compact(split(",", get_env("NOTIFICATION_WEBHOOK_URLS", "")))

    # Datadog only: auto-configure webhook custom JSON payload (Zenduty-friendly default).
    webhook_custom_payload_enabled = true
    # Optional override; null = default payload with $ALERT_ID, $EVENT_TITLE, $TEXT_ONLY_MSG, etc.
    # webhook_custom_payload = { alert_id = "$ALERT_ID", title = "$EVENT_TITLE", ... }
    webhook_custom_payload = null

    # Datadog monitors only (when datadog.enabled = true)
    notify_no_data    = true
    no_data_timeframe = 15
    renotify_interval = 30
  }

  #################### Application ##########################

  # --- Export Details (provider.yaml for Helm) ---
  # Generates k8s/values/provider.yaml consumed by helmfile. Cloud-specific values (Key Vault URI, WIF, GCS bucket)
  # are pulled from other module outputs automatically; only shared settings need to be configured here.
  # When cloudsql.create = true, database connection details are also included.
  # Private-registry image-pull auth (deployment-wide): governs both creating the
  # divyam-artifactory-docker-auth secret (0-divyam_secrets) and injecting the pull secret
  # into provider.yaml (3-export_details). Derived by cloud; override to true for GCP when
  # the container registry (GAR) is in a different project than the deployment.
  image_pull_secret_enabled = local.cloud_provider == "azure" ? true : false

  export_details = {
    cluster_domain = ""
    output_dir     = "k8s/helm-values"
  }

  # --- Ingress inputs (GKE-Ingress-referenced GCP resources: static IPs, managed SSL certs, Cloud Armor) ---
  # Managed by 2-app/4-ingress_inputs. Empty by default; populate per env (see defaults-gcp-prod.hcl).
  # The LB frontend (proxies/url-maps/backends/forwarding rules) is owned by the GKE ingress controller.
  # The switch console and inference hosts share one IP and one certificate.
  ingress_inputs = {
    static_ips = [
      { name = "${local.deployment_prefix}-switch-static-ip" },
    ]
    ssl_certs = [
      { name = "${local.deployment_prefix}-switch-ssl-cert", domains = ["console.demo.divyam.ai", "api.demo.divyam.ai"] },
      { name = "${local.deployment_prefix}-switch-preview-ssl-cert", domains = ["console.preview.divyam.ai", "api.preview.divyam.ai"] },
    ]
    # self-serve-ingress attaches this to all three backends through ingress.gcp.security_policy_name.
    cloud_armor_policies = [
      {
        name        = "${local.deployment_prefix}-switch-cloud-armor-policy"
        description = "Cloud Armor policy for the switch console and inference API"
        rules = [
          {
            priority      = 2000
            action        = "rate_based_ban"
            description   = "Rate limit per client IP"
            src_ip_ranges = ["*"]
            rate_limit = {
              conform_action       = "allow"
              exceed_action        = "deny(429)"
              enforce_on_key       = "IP"
              rate_limit_threshold = { count = 1000, interval_sec = 60 }
              ban_duration_sec     = 300
              ban_threshold        = { count = 5000, interval_sec = 120 }
            }
          },
          {
            priority      = 2147483647
            action        = "allow"
            description   = "Default allow rule"
            src_ip_ranges = ["*"]
          },
        ]
      },
    ]
  }

  # If not create, can setup mysql inside K8s. Default is inside K8s
  cloudsql = {
    create                        = true
    create_private_service_access = false # the vnet owns it
    instance_name                 = "${local.deployment_prefix}-cloudsql"
  }

  # Self-serve managed Postgres (Cloud SQL), brought up only when self-serve is in the stack list.
  # Sizing/HA matches cloudsql above (db-f1-micro, zonal); backups use Postgres point-in-time recovery.
  # Uses the private service access the vnet creates.
  cloudsql_postgres = {
    create                        = local.self_serve_in_stack
    create_private_service_access = false
    instance_name                 = "${local.deployment_prefix}-cloudsql-pg"
    database_version              = "POSTGRES_16"
    tier                          = "db-f1-micro"
    # ENTERPRISE required for the shared-core db-f1-micro tier; ENTERPRISE_PLUS rejects it.
    edition = "ENTERPRISE"
  }

  # --- Terraform outputs file for Helm ---
  # Path (relative to repo root) with filename and extension. Use .yaml or .json for format.
  # Dynamic placeholders (resolved from ENV/ORG_NAME when the script runs): ${local.deployment_prefix}, ${local.env_name}, ${local.org_name}
  outputs_file_path = "outputs/outputs-${local.deployment_prefix}.yaml"
}