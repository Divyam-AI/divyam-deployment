#!/usr/bin/env bash
# Sample deploy: set required env vars and run terragrunt plan.
# Replace placeholder values with your own before apply.
#
# Usage:
#   ./scripts/sample_deploy.sh  <gcp|azure>
#
# Optional: use local backend (no remote state, no Azure/GCS backend access) for testing:
#   TG_USE_LOCAL_BACKEND=1 ./sample_deploy.sh azure

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/" && pwd)"
cd "$REPO_ROOT"

if [ -z "${1:-}" ]; then
    echo "Error: CLOUD PROVIDER is required as argument (gcp|azure)"
    exit 1
fi

export CLOUD_PROVIDER="${1}"

# --- Required (values/*.hcl) ---
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

echo "ENV=$ENV CLOUD_PROVIDER=$CLOUD_PROVIDER REGION=$REGION ZONE=$ZONE ORG_NAME=$ORG_NAME${TG_USE_LOCAL_BACKEND:+ TG_USE_LOCAL_BACKEND=$TG_USE_LOCAL_BACKEND (local backend)}"
#echo "Running terragrunt run-all plan in 0-foundation (cloud=${CLOUD_PROVIDER} only)..."
# --filter limits run to this cloud's folders (e.g. 0-foundation/**/azure or /**/gcp)
#exec bash -c "cd \"$REPO_ROOT/0-foundation\" && terragrunt run --all plan --filter './**/${CLOUD_PROVIDER}'"
exec bash -c "terragrunt run --all plan --filter './**/${CLOUD_PROVIDER}'"