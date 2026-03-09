#!/usr/bin/env bash
# Sample deploy: set required env vars and run terragrunt plan/apply/import/etc.
# Replace placeholder values with your own before apply.
# Root reads config from VALUES_FILE (default: values/defaults.hcl). Override with VALUES_FILE env or last optional arg.
#
# Usage (plan/apply/destroy/...):
#   ./sample_deploy.sh <plan|apply|destroy|...> <0|1|2> <gcp|azure> [values_file]
#
# Usage (import state for a single module, e.g. 0-resource_scope):
#   ./sample_deploy.sh import <0|1|2> <gcp|azure> <module_path> <resource_address> <resource_id> [values_file]
#   Example (GCP): ./sample_deploy.sh import 0 gcp 0-resource_scope 'google_project.project[0]' pre-production-project
#   Example (Azure): ./sample_deploy.sh import 0 azure 0-resource_scope 'azurerm_resource_group.rd[0]' /subscriptions/.../resourceGroups/my-rg
#
# Arguments:
#   plan|apply|destroy|import|... - terragrunt command
#   0 - run in 0-foundation, 1 - 1-platform, 2 - 2-app
#   gcp|azure - cloud provider
#   For import only: module_path (e.g. 0-resource_scope), resource_address, resource_id
#   values_file - optional (default: values/defaults.hcl). Set VALUES_FILE for root.hcl.
#
# Optional: use local backend (no remote state) for testing:
#   TG_USE_LOCAL_BACKEND=1 ./sample_deploy.sh plan 0 azure
#
# --- Import examples (all use TF_VAR_import_mode=1 automatically) ---
# Replace <resource-id> with the actual cloud resource ID (project ID, ARM ID, etc.).
#
# 0-foundation:
#   GCP 0-resource_scope (project):
#     ./sample_deploy.sh import 0 gcp 0-resource_scope 'google_project.project[0]' <project-id>
#   Azure 0-resource_scope (resource group):
#     ./sample_deploy.sh import 0 azure 0-resource_scope 'azurerm_resource_group.rd[0]' /subscriptions/<sub-id>/resourceGroups/<rg-name>
#   GCP 1-apis (one import per enabled API; ID = project_id/service):
#     ./sample_deploy.sh import 0 gcp 1-apis 'google_project_service.enabled_apis["compute.googleapis.com"]' <project-id>/compute.googleapis.com
#     (repeat for each API). Or import all default APIs in one step:
#     ./sample_deploy.sh import 0 gcp 1-apis google_project_service.enabled_apis <project-id> [values_file]
#   GCP 1-vnet (VPC / subnet / app_gw_subnet):
#     ./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_network.vpc[0]' projects/<project>/global/networks/<vpc-name>
#     ./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_subnetwork.subnet[0]' projects/<project>/regions/<region>/subnetworks/<subnet-name>
#     ./sample_deploy.sh import 0 gcp 1-vnet 'google_compute_subnetwork.app_gw_subnet[0]' projects/<project>/regions/<region>/subnetworks/<app-gw-subnet-name>
#   Azure 1-vnet (VNet / subnet / app_gw_subnet):
#     ./sample_deploy.sh import 0 azure 1-vnet 'azurerm_virtual_network.vnet[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>
#     ./sample_deploy.sh import 0 azure 1-vnet 'azurerm_subnet.subnet[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet-name>
#     ./sample_deploy.sh import 0 azure 1-vnet 'azurerm_subnet.app_gw_subnet[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<app-gw-subnet-name>
#   GCP 2-terraform_state_blob_storage (GCS bucket):
#     ./sample_deploy.sh import 0 gcp 2-terraform_state_blob_storage 'google_storage_bucket.terraform[0]' <bucket-name>
#   Azure 2-terraform_state_blob_storage (storage account / container):
#     ./sample_deploy.sh import 0 azure 2-terraform_state_blob_storage 'azurerm_storage_account.terraform[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account-name>
#     ./sample_deploy.sh import 0 azure 2-terraform_state_blob_storage 'azurerm_storage_container.container[0]' https://<account>.blob.core.windows.net/<container-name>
#   GCP 2-nat (Cloud Router / NAT):
#     ./sample_deploy.sh import 0 gcp 2-nat 'google_compute_router.egress_nat_router[0]' <project>/<region>/<router-name>
#     ./sample_deploy.sh import 0 gcp 2-nat 'google_compute_router_nat.nat_config[0]' <project>/<region>/<router-name>/<nat-config-name>
#   Azure 2-nat (public IP / NAT gateway):
#     ./sample_deploy.sh import 0 azure 2-nat 'azurerm_public_ip.nat[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/publicIPAddresses/<pip-name>
#     ./sample_deploy.sh import 0 azure 2-nat 'azurerm_nat_gateway.nat[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/natGateways/<nat-name>
#   GCP 3-bastion (firewall / instance):
#     ./sample_deploy.sh import 0 gcp 3-bastion 'google_compute_firewall.iap_ssh[0]' projects/<project>/global/firewalls/allow-ssh-<bastion-name>
#     ./sample_deploy.sh import 0 gcp 3-bastion 'google_compute_instance.bastion[0]' projects/<project>/zones/<zone>/instances/<bastion-name>
#   Azure 3-bastion (NIC / public IP / NSG / VM / etc.):
#     ./sample_deploy.sh import 0 azure 3-bastion 'azurerm_network_interface.bastion_nic[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/networkInterfaces/<nic-name>
#     ./sample_deploy.sh import 0 azure 3-bastion 'azurerm_public_ip.bastion_pip[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/publicIPAddresses/<pip-name>
#     ./sample_deploy.sh import 0 azure 3-bastion 'azurerm_network_security_group.bastion_nsg[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/networkSecurityGroups/<nsg-name>
#     ./sample_deploy.sh import 0 azure 3-bastion 'azurerm_linux_virtual_machine.bastion[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/<vm-name>
#
# 1-platform:
#   GCP 0-divyam_secrets (Secret Manager secret):
#     ./sample_deploy.sh import 1 gcp 0-divyam_secrets 'google_secret_manager_secret.secrets["<secret-name>"]' projects/<project>/secrets/<secret-id>
#   Azure 0-divyam_secrets (Key Vault / secret):
#     ./sample_deploy.sh import 1 azure 0-divyam_secrets 'azurerm_key_vault.this[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>
#     ./sample_deploy.sh import 1 azure 0-divyam_secrets 'azurerm_key_vault_secret.secrets["<secret-name>"]' https://<vault-name>.vault.azure.net/secrets/<secret-name>
#   Azure 1-k8s (AKS cluster):
#     ./sample_deploy.sh import 1 azure 1-k8s 'azurerm_kubernetes_cluster.aks_cluster[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<cluster-name>
#
# 2-app:
#   Azure 0-cloudsql (MySQL Flexible Server / database / subnet / DNS zone):
#     ./sample_deploy.sh import 2 azure 0-cloudsql 'azurerm_mysql_flexible_server.default[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.DBforMySQL/flexibleServers/<server-name>
#     ./sample_deploy.sh import 2 azure 0-cloudsql 'azurerm_mysql_flexible_database.default[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.DBforMySQL/flexibleServers/<server>/databases/<db-name>
#     ./sample_deploy.sh import 2 azure 0-cloudsql 'azurerm_subnet.mysql[0]' /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<mysql-subnet-name>
#
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/" && pwd)"
cd "$REPO_ROOT"

if [ -z "${1:-}" ]; then
    echo "Error: TG_CMD is required as first argument (e.g. plan, apply, destroy)"
    exit 1
fi
if [ -z "${2:-}" ]; then
    echo "Error: LAYER is required as second argument (0=0-foundation, 1=1-platform, 2=2-app)"
    exit 1
fi
if [ -z "${3:-}" ]; then
    echo "Error: CLOUD PROVIDER is required as third argument (gcp|azure)"
    exit 1
fi

TG_CMD="${1}"
LAYER="${2}"
export CLOUD_PROVIDER="${3}"

if [ "${TG_CMD}" == "import" ]; then
    if [ -z "${4:-}" ] || [ -z "${5:-}" ] || [ -z "${6:-}" ]; then
        echo "Error: import requires module_path, resource_address, and resource_id."
        echo "  Usage: ./sample_deploy.sh import <0|1|2> <gcp|azure> <module_path> <resource_address> <resource_id> [values_file]"
        echo "  Example: ./sample_deploy.sh import 0 gcp 0-resource_scope 'google_project.project[0]' pre-production-project"
        exit 1
    fi
    MODULE_PATH="${4}"
    IMPORT_ADDRESS="${5}"
    IMPORT_ID="${6}"
    export VALUES_FILE="${7:-values/defaults.hcl}"
else
    export VALUES_FILE="${4:-values/defaults.hcl}"
fi

if [ "${LAYER}" != "0" ] && [ "${LAYER}" != "1" ] && [ "${LAYER}" != "2" ]; then
    echo "Error: LAYER must be 0, 1, or 2 (got: ${LAYER})"
    exit 1
fi
if [ "${CLOUD_PROVIDER}" != "azure" ] && [ "${CLOUD_PROVIDER}" != "gcp" ]; then
    echo "Error: CLOUD PROVIDER must be gcp or azure (got: ${CLOUD_PROVIDER})"
    exit 1
fi

if [ "${LAYER}" == "0" ]; then
    TG_DIR="0-foundation"
elif [ "${LAYER}" == "1" ]; then
    TG_DIR="1-platform"
else
    TG_DIR="2-app"
fi

# --- Required (fed into values file via get_env) ---
export ENV="${ENV:-dev}"

if [ "${CLOUD_PROVIDER}" == "azure" ]; then
    export REGION="${REGION:-southindia}"
    export ZONE="${ZONE:-southindia-1}"
    # https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2 -> Subscription ID
    export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-8645e690-451d-45a4-b10c-159705f63a22}"
    # https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Overview -> Tenant ID
    export ARM_TENANT_ID="${ARM_TENANT_ID:-ed5c6a8e-5949-4fbb-a0ec-08dbce5cc47e}"
elif [ "${CLOUD_PROVIDER}" == "gcp" ]; then
    export REGION="${REGION:-asia-south1}"
    export ZONE="${ZONE:-asia-south1-a}"
    # Billing account ID for new project (0-resource_scope); required when resource_scope.create=true
    export BILLING_ACCOUNT="${BILLING_ACCOUNT:-}"
fi

# --- Cloud credentials pre-flight (fail fast with clear instructions) ---
# Supports: GCP (Application Default Credentials or GOOGLE_APPLICATION_CREDENTIALS service account key);
#           Azure (az login or ARM_* service principal env vars).
check_cloud_credentials() {
    if [ "${CLOUD_PROVIDER}" == "gcp" ]; then
        # Service account key file (e.g. CI or VM)
        if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
            if grep -q '"client_email"' "${GOOGLE_APPLICATION_CREDENTIALS}" 2>/dev/null; then
                echo "GCP credentials OK (service account key: GOOGLE_APPLICATION_CREDENTIALS)."
                return
            fi
        fi
        # Application Default Credentials (gcloud or other ADC)
        if ! command -v gcloud &>/dev/null; then
            echo "Error: GCP credentials not found. Either:"
            echo "  1. Set GOOGLE_APPLICATION_CREDENTIALS to a service account key JSON file, or"
            echo "  2. Install gcloud and run: gcloud auth application-default login"
            exit 1
        fi
        if ! gcloud auth application-default print-access-token &>/dev/null; then
            echo "Error: GCP Application Default Credentials are not configured or have expired."
            echo "Run: gcloud auth application-default login"
            echo "Or set GOOGLE_APPLICATION_CREDENTIALS to a service account key JSON file."
            exit 1
        fi
        if ! gcloud projects list --limit=1 &>/dev/null; then
            echo "Error: GCP credentials are invalid or need re-authentication (e.g. reauth related error)."
            echo "Run: gcloud auth login"
            exit 1
        fi
        echo "GCP credentials OK (Application Default Credentials)."
    elif [ "${CLOUD_PROVIDER}" == "azure" ]; then
        # Service principal (ARM_* env vars)
        if [ -n "${ARM_CLIENT_ID:-}" ] && [ -n "${ARM_CLIENT_SECRET:-}" ] && [ -n "${ARM_SUBSCRIPTION_ID:-}" ] && [ -n "${ARM_TENANT_ID:-}" ]; then
            echo "Azure credentials OK (ARM_* service principal)."
            return
        fi
        # Azure CLI (az login)
        if ! command -v az &>/dev/null; then
            echo "Error: Azure credentials not found. Either:"
            echo "  1. Export ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, or"
            echo "  2. Install Azure CLI and run: az login"
            exit 1
        fi
        if ! az account show &>/dev/null; then
            echo "Error: Not logged in to Azure, or session expired."
            echo "Run: az login"
            echo "Or export ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID."
            exit 1
        fi
        echo "Azure credentials OK (az account)."
    fi
}
check_cloud_credentials

# --- Optional common ---
export ORG_NAME="${ORG_NAME:-}"
export TG_USE_LOCAL_BACKEND="${TG_USE_LOCAL_BACKEND:-1}"

if [ "${TG_CMD}" == "import" ]; then
    MODULE_DIR="$REPO_ROOT/$TG_DIR/$MODULE_PATH/$CLOUD_PROVIDER"
    if [ ! -d "${MODULE_DIR}" ]; then
        echo "Error: Module directory not found: ${MODULE_DIR}"
        exit 1
    fi
    echo "ENV=$ENV CLOUD_PROVIDER=$CLOUD_PROVIDER REGION=$REGION LAYER=$LAYER TG_DIR=$TG_DIR MODULE=$MODULE_PATH/$CLOUD_PROVIDER VALUES_FILE=$VALUES_FILE${TG_USE_LOCAL_BACKEND:+ TG_USE_LOCAL_BACKEND=$TG_USE_LOCAL_BACKEND (local backend)}"
    echo "Running terragrunt import in $MODULE_DIR..."

    # GCP 1-apis: import all default APIs in one step when address is google_project_service.enabled_apis and id is project_id (no slash)
    IMPORT_ALL_APIS=false
    if [ "${MODULE_PATH}" = "1-apis" ] && [ "${CLOUD_PROVIDER}" = "gcp" ] && \
       [ "${IMPORT_ADDRESS}" = "google_project_service.enabled_apis" ] && [ "${IMPORT_ID#*/}" = "${IMPORT_ID}" ]; then
        IMPORT_ALL_APIS=true
    fi

    if [ "${IMPORT_ALL_APIS}" = true ]; then
        PROJECT_ID="${IMPORT_ID}"
        GCP_DEFAULT_APIS=(
            "compute.googleapis.com"
            "container.googleapis.com"
            "iam.googleapis.com"
            "storage.googleapis.com"
            "logging.googleapis.com"
            "monitoring.googleapis.com"
            "secretmanager.googleapis.com"
            "dns.googleapis.com"
            "networkmanagement.googleapis.com"
            "servicenetworking.googleapis.com"
        )
        TG_EXIT=0
        for api in "${GCP_DEFAULT_APIS[@]}"; do
            echo "Importing ${api}..."
            if (bash -c "cd \"$MODULE_DIR\" && terragrunt import 'google_project_service.enabled_apis[\"${api}\"]' \"${PROJECT_ID}/${api}\""); then
                :
            else
                echo "  -> skip (not enabled or already in state)"
            fi
        done
    else
        export TF_VAR_import_mode=1
        bash -c "cd \"$MODULE_DIR\" && terragrunt import \"$IMPORT_ADDRESS\" \"$IMPORT_ID\""
        TG_EXIT=$?
        unset TF_VAR_import_mode
    fi
else
echo "ENV=$ENV CLOUD_PROVIDER=$CLOUD_PROVIDER REGION=$REGION ZONE=$ZONE ORG_NAME=$ORG_NAME LAYER=$LAYER TG_DIR=$TG_DIR VALUES_FILE=$VALUES_FILE${TG_USE_LOCAL_BACKEND:+ TG_USE_LOCAL_BACKEND=$TG_USE_LOCAL_BACKEND (local backend)}"
echo "Running terragrunt run-all $TG_CMD in $TG_DIR (cloud=${CLOUD_PROVIDER})..."
bash -c "cd \"$REPO_ROOT/$TG_DIR\" && terragrunt run --all $TG_CMD --filter './**/${CLOUD_PROVIDER}'"
TG_EXIT=$?
fi

# After a successful apply, write Terraform outputs to the file path configured in values file (extension sets YAML vs JSON)
if [[ "${TG_EXIT}" -eq 0 && "${TG_CMD}" == "apply" ]]; then
  if [[ -x "$REPO_ROOT/scripts/write-outputs-yaml.sh" ]]; then
    echo "Skipping ...Writing Terraform outputs (path from ${VALUES_FILE})..."
#    "$REPO_ROOT/scripts/write-outputs-yaml.sh" "${LAYER}" "${CLOUD_PROVIDER}" "${REPO_ROOT}" "${VALUES_FILE}" || true
  fi
fi

exit "${TG_EXIT}"