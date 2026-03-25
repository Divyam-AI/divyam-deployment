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
    else
        echo "Error: Invalid cloud provider: ${CLOUD_PROVIDER}"
        exit 1
    fi
}
if [ -z "${CLOUD_PROVIDER:-}" ]; then
    echo "Error: CLOUD_PROVIDER environment variable is not set."
    echo "Please set CLOUD_PROVIDER to 'gcp' or 'azure' and re-run the script."
    exit 1
fi

check_cloud_credentials