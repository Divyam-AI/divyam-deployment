#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# check_cloud_credentials.sh — cloud credentials pre-flight (fail fast with clear instructions).
#
# Supports:
#   GCP   — Application Default Credentials, or GOOGLE_APPLICATION_CREDENTIALS service-account key.
#   Azure — `az login` session, or ARM_* service-principal env vars.
#
# Usage:
#   CLOUD_PROVIDER=gcp|azure scripts/check_cloud_credentials.sh
#   scripts/check_cloud_credentials.sh --help
set -euo pipefail

case "${1:-}" in
  -h|--help) grep '^#' "$0" | grep -vE '^#(!|[[:space:]]*SPDX-)' | sed 's/^# \{0,1\}//'; exit 0;;
  "") ;;
  *) echo "unknown arg: $1 (use --help)" >&2; exit 2;;
esac

# Validate a GCP service-account key JSON has a client_email (best-effort, tool-aware).
gcp_key_has_client_email() {
  local f="$1"
  if command -v jq >/dev/null 2>&1; then jq -e '.client_email' "$f" >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("client_email") else 1)' "$f" 2>/dev/null
  else grep -q '"client_email"' "$f" 2>/dev/null; fi
}

check_cloud_credentials() {
  case "${CLOUD_PROVIDER:-}" in
    gcp)
      # Service-account key file (e.g. CI or VM).
      if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
        if gcp_key_has_client_email "${GOOGLE_APPLICATION_CREDENTIALS}"; then
          echo "GCP credentials OK (service-account key: GOOGLE_APPLICATION_CREDENTIALS)."
          return 0
        fi
        echo "Error: GOOGLE_APPLICATION_CREDENTIALS points to a file without a client_email — not a valid SA key." >&2
        exit 1
      fi
      # Application Default Credentials (gcloud or other ADC).
      if ! command -v gcloud >/dev/null 2>&1; then
        echo "Error: GCP credentials not found. Either:" >&2
        echo "  1. Set GOOGLE_APPLICATION_CREDENTIALS to a service-account key JSON file, or" >&2
        echo "  2. Install gcloud and run: gcloud auth application-default login" >&2
        exit 1
      fi
      if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
        echo "Error: GCP Application Default Credentials are not configured or have expired." >&2
        echo "Run: gcloud auth application-default login (or set GOOGLE_APPLICATION_CREDENTIALS)." >&2
        exit 1
      fi
      if ! gcloud projects list --limit=1 >/dev/null 2>&1; then
        echo "Error: GCP credentials are invalid or need re-authentication." >&2
        echo "Run: gcloud auth login" >&2
        exit 1
      fi
      echo "GCP credentials OK (Application Default Credentials)."
      ;;
    azure)
      # Service principal (ARM_* env vars) — preferred for non-interactive runs.
      if [[ -n "${ARM_CLIENT_ID:-}" && -n "${ARM_CLIENT_SECRET:-}" && -n "${ARM_SUBSCRIPTION_ID:-}" && -n "${ARM_TENANT_ID:-}" ]]; then
        echo "Azure credentials OK (ARM_* service principal)."
        return 0
      fi
      # Otherwise fall back to an interactive `az login` session.
      if ! command -v az >/dev/null 2>&1; then
        echo "Error: Azure CLI not found. Either:" >&2
        echo "  1. Export ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, or" >&2
        echo "  2. Install Azure CLI and run: az login" >&2
        exit 1
      fi
      if ! az account show >/dev/null 2>&1; then
        echo "Error: Not logged in to Azure, or session expired." >&2
        echo "Run: az login  (or export the four ARM_* service-principal variables)." >&2
        exit 1
      fi
      echo "Azure credentials OK (az login session)."
      # Informational only — an az-login session is valid; ARM_* are needed for non-interactive (CI) runs.
      local missing=""
      for v in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_SUBSCRIPTION_ID ARM_TENANT_ID; do
        [[ -z "${!v:-}" ]] && missing="${missing}${missing:+ }${v}"
      done
      [[ -n "$missing" ]] && echo "Note: using your interactive session; for CI/non-interactive runs also set: ${missing}"
      ;;
    "")
      echo "Error: CLOUD_PROVIDER is not set. Set it to 'gcp' or 'azure' and re-run." >&2
      exit 1
      ;;
    *)
      echo "Error: invalid CLOUD_PROVIDER: ${CLOUD_PROVIDER} (expected gcp|azure)." >&2
      exit 1
      ;;
  esac
}

check_cloud_credentials
