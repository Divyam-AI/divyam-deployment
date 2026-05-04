#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  cd_deploy.sh --provider <gcp|azure> --values-dir <path> [options]

Required:
  --provider <gcp|azure>      Cloud provider used by target cluster.
  --values-dir <path>         HELMFILE values directory.

Optional:
  --helmfile <path>           Helmfile template path (default: helmfile.yaml.gotmpl).
  --cluster-name <name>       Cluster name (required for provider auth).
  --region <name>             Region for GCP get-credentials.
  --project <name>            GCP project for get-credentials.
  --resource-group <name>     Azure resource group for AKS get-credentials.
  --selector <release-name>   Optional release selector for targeted deploy.
  --dry-run                   Print planned commands only.
  -h, --help                  Show help.

Secrets (from pipeline secret manager — see docs/cicd-overview.md):
  GCP:  GCP_SA_KEY_JSON → write to file, set GOOGLE_APPLICATION_CREDENTIALS
  Azure: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID

Examples:
  ./cd_deploy.sh --provider gcp --values-dir ./helm-values \
    --cluster-name divyam-gke-prod-1-asia-south1 --region asia-south1 --project divyam-production

  ./cd_deploy.sh --provider azure --values-dir ./helm-values \
    --cluster-name <cluster> --resource-group <rg> --selector divyam-control-plane-prod
EOF
}

PROVIDER=""
VALUES_DIR=""
HELMFILE_FILE="helmfile.yaml.gotmpl"
CLUSTER_NAME=""
REGION=""
PROJECT=""
RESOURCE_GROUP=""
SELECTOR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --values-dir) VALUES_DIR="$2"; shift 2 ;;
    --helmfile) HELMFILE_FILE="$2"; shift 2 ;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --selector) SELECTOR="$2"; shift 2 ;;
    --dry-run) PIPELINE_DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PROVIDER" || -z "$VALUES_DIR" ]]; then
  echo "Error: --provider and --values-dir are required." >&2
  usage
  exit 1
fi

export PIPELINE_DRY_RUN="${PIPELINE_DRY_RUN:-false}"

echo "=== CD deploy: provider=$PROVIDER values=$VALUES_DIR helmfile=$HELMFILE_FILE selector=${SELECTOR:-<none>} ==="

# TODO(SRE): Materialize GCP_SA_KEY_JSON to a temp file and export GOOGLE_APPLICATION_CREDENTIALS before GCP auth.

case "$PROVIDER" in
  gcp)
    if [[ -z "$CLUSTER_NAME" || -z "$REGION" || -z "$PROJECT" ]]; then
      echo "Error: GCP flow requires --cluster-name --region --project." >&2
      exit 1
    fi
    pipeline_auth_gcp "$CLUSTER_NAME" "$REGION" "$PROJECT"
    ;;
  azure)
    if [[ -z "$CLUSTER_NAME" || -z "$RESOURCE_GROUP" ]]; then
      echo "Error: Azure flow requires --cluster-name --resource-group." >&2
      exit 1
    fi
    pipeline_auth_azure "$CLUSTER_NAME" "$RESOURCE_GROUP"
    ;;
  *)
    echo "Error: unsupported provider '$PROVIDER'. Expected gcp or azure." >&2
    exit 1
    ;;
esac

pipeline_kube_smoke

export HELMFILE_VALUES_DIR="$VALUES_DIR"

if [[ -n "$SELECTOR" ]]; then
  pipeline_run "helmfile -f \"$HELMFILE_FILE\" -l name=\"$SELECTOR\" apply"
else
  pipeline_run "helmfile -f \"$HELMFILE_FILE\" apply"
fi

echo "CD deployment successful."
