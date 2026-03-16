# Pre-prod import: use VALUES_FILE=divyam-pre-prod-defaults.hcl so deployment_prefix/names match.
# Run from repo root. Optional: set TG_USE_LOCAL_BACKEND=0 for remote state.
#
# For Azure imports: set ARM_SUBSCRIPTION_ID (required). RG_NAME defaults to pre-prod resource group.
#   export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
#   export RG_NAME="rg-sudhir-4084"   # or your resource group name from values file

VALUES_FILE="${VALUES_FILE:-divyam-pre-prod-defaults.hcl}"

# Azure: build subscription/resource-group prefix for ARM IDs (set ARM_SUBSCRIPTION_ID before running Azure section)
SUB="${ARM_SUBSCRIPTION_ID:+}/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME:-rg-sudhir-4084}"
RG_NAME="${RG_NAME:-rg-sudhir-4084}"

# ------------------------------------------------------------------------------
# Azure imports (set ARM_SUBSCRIPTION_ID and RG_NAME before running)
# ------------------------------------------------------------------------------
_azure_imports() {
  if [ -z "${ARM_SUBSCRIPTION_ID:-}" ]; then
    echo "Skipping Azure imports: ARM_SUBSCRIPTION_ID not set."
    return 0
  fi
  local sub="/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}"

  # 0-foundation/0-resource_scope (resource group)
  ./sample_deploy.sh import 0-foundation/0-resource_scope azure 'azurerm_resource_group.rd[0]' "${sub}" "$VALUES_FILE"

  # 0-foundation/0-apis (resource provider registrations). Import each: azurerm_resource_provider_registration.providers["Microsoft.Compute"] etc.
  # ./sample_deploy.sh import 0-foundation/0-apis azure 'azurerm_resource_provider_registration.providers["Microsoft.Compute"]' "${sub}/providers/Microsoft.Resources/providers/Microsoft.Compute" "$VALUES_FILE"

  # 0-foundation/1-vnet (VNet and subnets)
  ./sample_deploy.sh import 0-foundation/1-vnet azure 'azurerm_virtual_network.vnet[0]' "${sub}/providers/Microsoft.Network/virtualNetworks/rg-sudhir-4084-vnet" "$VALUES_FILE"
  ./sample_deploy.sh import 0-foundation/1-vnet azure 'azurerm_subnet.subnet[0]' "${sub}/providers/Microsoft.Network/virtualNetworks/rg-sudhir-4084-vnet/subnets/rg-sudhir-4084-subnet" "$VALUES_FILE"
  ./sample_deploy.sh import 0-foundation/1-vnet azure 'azurerm_subnet.app_gw_subnet[0]' "${sub}/providers/Microsoft.Network/virtualNetworks/rg-sudhir-4084-vnet/subnets/rg-sudhir-4084-app-gw-subnet" "$VALUES_FILE"

  # 0-foundation/2-nat (public IP, NAT gateway; associations are managed by Terraform after)
  ./sample_deploy.sh import 0-foundation/2-nat azure 'azurerm_public_ip.nat[0]' "${sub}/providers/Microsoft.Network/publicIPAddresses/divyam-pre-prod-nat-ip-4084" "$VALUES_FILE"
  ./sample_deploy.sh import 0-foundation/2-nat azure 'azurerm_nat_gateway.nat[0]' "${sub}/providers/Microsoft.Network/natGateways/divyam-pre-prod-nat-gateway" "$VALUES_FILE"

  # 0-foundation/2-terraform_state_blob_storage (storage account, container)
  ./sample_deploy.sh import 0-foundation/2-terraform_state_blob_storage azure 'azurerm_storage_account.terraform[0]' "${sub}/providers/Microsoft.Storage/storageAccounts/divyampreprodtfstate" "$VALUES_FILE"
  ./sample_deploy.sh import 0-foundation/2-terraform_state_blob_storage azure 'azurerm_storage_container.container[0]' "https://divyampreprodtfstate.blob.core.windows.net/divyampreprodtfstate" "$VALUES_FILE"

  # 0-foundation/3-bastion (NIC, public IP, NSG, rule, VM)
  ./sample_deploy.sh import 0-foundation/3-bastion azure 'azurerm_network_interface.bastion_nic[0]' "${sub}/providers/Microsoft.Network/networkInterfaces/divyam-pre-prod-bastion-nic" "$VALUES_FILE"
  ./sample_deploy.sh import 0-foundation/3-bastion azure 'azurerm_public_ip.bastion_pip[0]' "${sub}/providers/Microsoft.Network/publicIPAddresses/divyam-pre-prod-bastion-pip" "$VALUES_FILE"
  ./sample_deploy.sh import 0-foundation/3-bastion azure 'azurerm_network_security_group.bastion_nsg[0]' "${sub}/providers/Microsoft.Network/networkSecurityGroups/divyam-pre-prod-bastion-nsg" "$VALUES_FILE"
  ./sample_deploy.sh import 0-foundation/3-bastion azure 'azurerm_linux_virtual_machine.bastion[0]' "${sub}/providers/Microsoft.Compute/virtualMachines/divyam-pre-prod-bastion" "$VALUES_FILE"

  # 1-platform/0-divyam_object_storage (storage account, container)
  ./sample_deploy.sh import 1-platform/0-divyam_object_storage azure 'azurerm_storage_account.this["divyam-preprod-storage"]' "${sub}/providers/Microsoft.Storage/storageAccounts/divyam-preprod-storage" "$VALUES_FILE"
  ./sample_deploy.sh import 1-platform/0-divyam_object_storage azure 'azurerm_storage_container.container["divyam-preprod-storage/divyam-preprod-gcs-router-raw-logs"]' "https://divyam-preprod-storage.blob.core.windows.net/divyam-preprod-gcs-router-raw-logs" "$VALUES_FILE"

  # 2-app/0-divyam_secrets (Key Vault and secrets)
  ./sample_deploy.sh import 2-app/0-divyam_secrets azure 'azurerm_key_vault.this[0]' "${sub}/providers/Microsoft.KeyVault/vaults/divyam-dev-vault-4048" "$VALUES_FILE"
  # ./sample_deploy.sh import 2-app/0-divyam_secrets azure 'azurerm_key_vault_secret.secrets["<secret-name>"]' "https://divyam-dev-vault-4048.vault.azure.net/secrets/<secret-name>" "$VALUES_FILE"

  # 1-platform/0-app_gw (App Gateway, public IP, identities, WAF, DNS zones, certs). Adjust names to match values file.
  ./sample_deploy.sh import 1-platform/0-app_gw azure 'azurerm_public_ip.lb_ip[0]' "${sub}/providers/Microsoft.Network/publicIPAddresses/divyam-pre-prod-ip" "$VALUES_FILE"
  ./sample_deploy.sh import 1-platform/0-app_gw azure 'azurerm_application_gateway.appgw[0]' "${sub}/providers/Microsoft.Network/applicationGateways/divyam-pre-prod-service" "$VALUES_FILE"
  ./sample_deploy.sh import 1-platform/0-app_gw azure 'azurerm_web_application_firewall_policy.waf[0]' "${sub}/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/divyam-pre-prod-waf" "$VALUES_FILE"

  # 1-platform/1-k8s (AKS cluster, node pools, log analytics, monitor, Grafana, identities)
  ./sample_deploy.sh import 1-platform/1-k8s azure 'azurerm_kubernetes_cluster.aks_cluster[0]' "${sub}/providers/Microsoft.ContainerService/managedClusters/divyam-pre-prod-k8s-cluster" "$VALUES_FILE"
  ./sample_deploy.sh import 1-platform/1-k8s azure 'azurerm_log_analytics_workspace.log_analytics_workspace[0]' "${sub}/providers/Microsoft.OperationalInsights/workspaces/divyam-pre-prod-k8s-cluster-logs" "$VALUES_FILE"
  ./sample_deploy.sh import 1-platform/1-k8s azure 'azurerm_monitor_workspace.prometheus[0]' "${sub}/providers/Microsoft.Monitor/accounts/divyam-pre-prod-k8s-cluster-prometheus" "$VALUES_FILE"
  ./sample_deploy.sh import 1-platform/1-k8s azure 'azurerm_dashboard_grafana.grafana[0]' "${sub}/providers/Microsoft.Dashboard/grafana/divyam-pre-prod-k8s-cluster-grafana" "$VALUES_FILE"

  # 2-app/1-iam_bindings (user-assigned identities, role assignments, key vault access, federated identity)
  # ./sample_deploy.sh import 2-app/1-iam_bindings azure 'azurerm_user_assigned_identity.identities["<identity-name>"]' "${sub}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>" "$VALUES_FILE"

  # 1-platform/2-alerts (action group, Prometheus rule group)
  # ./sample_deploy.sh import 1-platform/2-alerts azure 'azurerm_monitor_action_group.alerts[0]' "${sub}/providers/Microsoft.Insights/actionGroups/divyam-pre-prod-alerts" "$VALUES_FILE"

  # 2-app/0-cloudsql (MySQL Flexible Server, subnet, DNS zone, database - when create = true)
  # ./sample_deploy.sh import 2-app/0-cloudsql azure 'azurerm_mysql_flexible_server.default[0]' "${sub}/providers/Microsoft.DBforMySQL/flexibleServers/divyam-pre-prod-cloudsql" "$VALUES_FILE"
  # ./sample_deploy.sh import 2-app/0-cloudsql azure 'azurerm_mysql_flexible_database.default[0]' "${sub}/providers/Microsoft.DBforMySQL/flexibleServers/divyam-pre-prod-cloudsql/databases/<db-name>" "$VALUES_FILE"
}

# Run only Azure imports when first argument is "azure"
if [ "${1:-}" = "azure" ]; then
  _azure_imports
  exit 0
fi

# ------------------------------------------------------------------------------
# GCP imports (pre-production-project, asia-south1, divyam-pre-prod-*)
# ------------------------------------------------------------------------------

# 0-foundation/0-resource_scope (GCP project)
./sample_deploy.sh import 0-foundation/0-resource_scope gcp 'google_project.project[0]' pre-production-project "$VALUES_FILE"

# 0-foundation/0-apis (import all default APIs for project)
./sample_deploy.sh import 0-foundation/0-apis gcp google_project_service.enabled_apis pre-production-project "$VALUES_FILE"

# 0-foundation/1-vnet (VPC and subnets)
./sample_deploy.sh import 0-foundation/1-vnet gcp 'google_compute_network.vpc[0]' projects/pre-production-project/global/networks/default "$VALUES_FILE"
./sample_deploy.sh import 0-foundation/1-vnet gcp 'google_compute_subnetwork.subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/default "$VALUES_FILE"
./sample_deploy.sh import 0-foundation/1-vnet gcp 'google_compute_subnetwork.app_gw_subnet[0]' projects/pre-production-project/regions/asia-south1/subnetworks/proxy-only-subnet "$VALUES_FILE"

# 0-foundation/2-nat (Cloud Router and NAT)
./sample_deploy.sh import 0-foundation/2-nat gcp 'google_compute_router.egress_nat_router[0]' projects/pre-production-project/regions/asia-south1/routers/egress-nat-router-preprod "$VALUES_FILE"
./sample_deploy.sh import 0-foundation/2-nat gcp 'google_compute_router_nat.nat_config[0]' projects/pre-production-project/regions/asia-south1/routers/egress-nat-router-preprod/egress-nat-config-preprod "$VALUES_FILE"

# 0-foundation/2-terraform_state_blob_storage (GCS state bucket)
./sample_deploy.sh import 0-foundation/2-terraform_state_blob_storage gcp 'google_storage_bucket.terraform[0]' divyamdevtfstate "$VALUES_FILE"

# 0-foundation/3-bastion (firewall, instance)
./sample_deploy.sh import 0-foundation/3-bastion gcp 'google_compute_firewall.iap_ssh[0]' projects/pre-production-project/global/firewalls/allow-ssh-divyam-pre-prod-bastion "$VALUES_FILE"
./sample_deploy.sh import 0-foundation/3-bastion gcp 'google_compute_instance.bastion[0]' projects/pre-production-project/zones/asia-south1-a/instances/divyam-pre-prod-bastion "$VALUES_FILE"

# 1-platform/0-divyam_object_storage (GCS bucket). Key = storage_account_name/container_name from values. Run in module: terragrunt output import_keys_created
./sample_deploy.sh import 1-platform/0-divyam_object_storage gcp 'google_storage_bucket.this["divyam-preprod-storage/divyam-preprod-gcs-router-raw-logs"]' projects/pre-production-project/storage/buckets/divyam-preprod-gcs-router-raw-logs "$VALUES_FILE"

# 2-app/0-divyam_secrets (Secret Manager). Import each secret: google_secret_manager_secret.secrets["<name>"], then secret version if needed.
# ./sample_deploy.sh import 2-app/0-divyam_secrets gcp 'google_secret_manager_secret.secrets["<secret-name>"]' projects/pre-production-project/secrets/<secret-id> "$VALUES_FILE"

# 1-platform/0-app_gw (Load Balancer: SSL cert, IPs, health check, backend, URL maps, proxies, forwarding rules, WAF)
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_managed_ssl_certificate.lb_cert[0]' projects/pre-production-project/global/sslCertificates/divyam-pre-prod-service-lb-ssl-cert "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_global_address.static_ip[0]' projects/pre-production-project/global/addresses/divyam-pre-prod-service-backend-ip "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_address.internal[0]' projects/pre-production-project/regions/asia-south1/addresses/divyam-pre-prod-service-internal-lb-ip "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_health_check.default' projects/pre-production-project/global/httpHealthChecks/divyam-pre-prod-service-backend-elb-health-check "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_backend_service.default' projects/pre-production-project/global/backendServices/divyam-pre-prod-service-backend "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_url_map.default' projects/pre-production-project/global/urlMaps/divyam-pre-prod-service-backend-gke-url-map "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_url_map.http_redirect' projects/pre-production-project/global/urlMaps/divyam-pre-prod-service-backend-http-to-https-redirect-map "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_target_https_proxy.https' projects/pre-production-project/global/targetHttpsProxies/divyam-pre-prod-service-backend-https "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_target_http_proxy.http' projects/pre-production-project/global/targetHttpProxies/divyam-pre-prod-service-backend-http "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_global_forwarding_rule.https' projects/pre-production-project/global/forwardingRules/divyam-pre-prod-service-backend-https-forwarding-rule "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_global_forwarding_rule.http' projects/pre-production-project/global/forwardingRules/divyam-pre-prod-service-backend-http-forwarding-rule "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_forwarding_rule.internal' projects/pre-production-project/regions/asia-south1/forwardingRules/internal-https-rule "$VALUES_FILE"
./sample_deploy.sh import 1-platform/0-app_gw gcp 'google_compute_security_policy.waf[0]' projects/pre-production-project/global/securityPolicies/divyam-pre-prod-waf "$VALUES_FILE"

# 1-platform/1-k8s (GKE cluster and node pools). Cluster key = k8s.name from values (e.g. divyam-pre-prod-k8s-cluster).
./sample_deploy.sh import 1-platform/1-k8s gcp 'google_container_cluster.gke_cluster["divyam-pre-prod-k8s-cluster"]' projects/pre-production-project/locations/asia-south1/clusters/divyam-pre-prod-k8s-cluster "$VALUES_FILE"
# ./sample_deploy.sh import 1-platform/1-k8s gcp 'google_container_node_pool.additional["divyam-pre-prod-k8s-cluster-gpupool"]' projects/pre-production-project/locations/asia-south1/clusters/divyam-pre-prod-k8s-cluster/nodePools/gpupool "$VALUES_FILE"
# ./sample_deploy.sh import 1-platform/1-k8s gcp 'google_logging_project_bucket_config.default_bucket["_Default"]' projects/pre-production-project/locations/global/buckets/_Default "$VALUES_FILE"

# 2-app/1-iam_bindings (service accounts and IAM). Import keys from terragrunt output in module.
# ./sample_deploy.sh import 2-app/1-iam_bindings gcp 'google_service_account.identities["<sa-name>"]' projects/pre-production-project/serviceAccounts/<email> "$VALUES_FILE"

# 1-platform/2-alerts (notification channels: run in 1-platform/2-alerts/gcp/notification_channels and 1-platform/2-alerts/gcp/alerts)
# ./sample_deploy.sh import 1-platform/2-alerts/gcp/notification_channels gcp 'google_monitoring_notification_channel.email' projects/pre-production-project/notificationChannels/<channel-id> "$VALUES_FILE"

# 2-app/0-cloudsql (Cloud SQL, private IP, DB, user - only when cloudsql.create = true)
# ./sample_deploy.sh import 2-app/0-cloudsql gcp 'google_compute_global_address.private_ip_address[0]' projects/pre-production-project/global/addresses/divyam-pre-prod-cloudsql "$VALUES_FILE"
# ./sample_deploy.sh import 2-app/0-cloudsql gcp 'google_sql_database_instance.default[0]' projects/pre-production-project/instances/divyam-pre-prod-cloudsql "$VALUES_FILE"

# --- Dev example (values/defaults.hcl, project divyam-dev-rg) ---
# ORG_ID=1060883629618 BILLING_ACCOUNT="01FACA-EFA07C-B3BD77" ./sample_deploy.sh import 0-foundation/0-resource_scope gcp 'google_project.project[0]' divyam-dev-rg values/defaults.hcl
