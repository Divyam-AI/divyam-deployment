#!/usr/bin/env bash
# Sample deploy: set required env vars and run terragrunt plan.
# Replace placeholder values with your own before apply.
# Root reads config from VALUES_FILE (default: values/defaults.hcl). Override with 3rd arg or VALUES_FILE env.
#
# Usage:
#   ./sample_deploy.sh <plan|apply|...> <0|1|2> <gcp|azure> [values_file]
#
# Arguments:
#   plan|apply|destroy|... - terragrunt command (e.g. plan, apply, destroy)
#   0 - run terragrunt in 0-foundation
#   1 - run terragrunt in 1-platform
#   2 - run terragrunt in 2-app
#   gcp|azure - cloud provider
#   values_file - optional (default: values/defaults.hcl). Set VALUES_FILE for root.hcl.
#
# Optional: use local backend (no remote state) for testing:
#   TG_USE_LOCAL_BACKEND=1 ./sample_deploy.sh plan 0 azure

set -euo pipefail
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
export VALUES_FILE="${4:-values/defaults.hcl}"

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
    export REGION="${REGION:-eastus2}"
    export ZONE="${ZONE:-eastus2-1}"
    # https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2 -> Subscription ID
    export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-8645e690-451d-45a4-b10c-159705f63a22}"
    # https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Overview -> Tenant ID
    export ARM_TENANT_ID="${ARM_TENANT_ID:-ed5c6a8e-5949-4fbb-a0ec-08dbce5cc47e}"
elif [ "${CLOUD_PROVIDER}" == "gcp" ]; then
    export REGION="${REGION:-asia-south1}"
    export ZONE="${ZONE:-asia-south1-a}"
fi

# --- Optional common ---
export ORG_NAME="${ORG_NAME:-}"
export TG_USE_LOCAL_BACKEND="${TG_USE_LOCAL_BACKEND:-1}"

echo "ENV=$ENV CLOUD_PROVIDER=$CLOUD_PROVIDER REGION=$REGION ZONE=$ZONE ORG_NAME=$ORG_NAME LAYER=$LAYER TG_DIR=$TG_DIR VALUES_FILE=$VALUES_FILE${TG_USE_LOCAL_BACKEND:+ TG_USE_LOCAL_BACKEND=$TG_USE_LOCAL_BACKEND (local backend)}"
echo "Running terragrunt run-all $TG_CMD in $TG_DIR (cloud=${CLOUD_PROVIDER})..."
bash -c "cd \"$REPO_ROOT/$TG_DIR\" && terragrunt run --all $TG_CMD --filter './**/${CLOUD_PROVIDER}'"
TG_EXIT=$?

# After a successful apply, write Terraform outputs to the file path configured in values file (extension sets YAML vs JSON)
if [[ "${TG_EXIT}" -eq 0 && "${TG_CMD}" == "apply" ]]; then
  if [[ -x "$REPO_ROOT/scripts/write-outputs-yaml.sh" ]]; then
#    echo "Writing Terraform outputs (path from ${VALUES_FILE})..."
#    "$REPO_ROOT/scripts/write-outputs-yaml.sh" "${LAYER}" "${CLOUD_PROVIDER}" "${REPO_ROOT}" "${VALUES_FILE}" || true
  fi
fi

exit "${TG_EXIT}"