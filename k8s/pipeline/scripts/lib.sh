#!/usr/bin/env bash
# Shared helpers for pipeline/scripts/ci_validate.sh and cd_deploy.sh.
# shellcheck shell=bash
# Do not execute this file directly; it is meant to be sourced.

# pipeline_run — execute a command string, or print it in dry-run mode.
# Set PIPELINE_DRY_RUN=true before sourcing callers that use this.
pipeline_run() {
  if [[ "${PIPELINE_DRY_RUN:-false}" == "true" ]]; then
    echo "[dry-run] $*"
  else
    # shellcheck disable=SC2090,SC2086
    eval "$@"
  fi
}

# pipeline_auth_gcp — activate SA and merge kubeconfig for GKE.
# Expects GOOGLE_APPLICATION_CREDENTIALS to point at a key file (from secret manager).
pipeline_auth_gcp() {
  local cluster_name="$1"
  local region="$2"
  local project="$3"

  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" || ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
    echo "Error: GOOGLE_APPLICATION_CREDENTIALS must be set to a key file path (populate from GCP_SA_KEY_JSON in secret manager)." >&2
    exit 1
  fi

  pipeline_run "gcloud auth activate-service-account --key-file \"\$GOOGLE_APPLICATION_CREDENTIALS\""
  pipeline_run "gcloud container clusters get-credentials \"$cluster_name\" --region=\"$region\" --project=\"$project\""
}

# pipeline_auth_azure — service principal login and AKS kubeconfig.
# Uses ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID (from secret manager).
pipeline_auth_azure() {
  local cluster_name="$1"
  local resource_group="$2"

  for _v in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_SUBSCRIPTION_ID ARM_TENANT_ID; do
    if [[ -z "${!_v:-}" ]]; then
      echo "Error: ${_v} must be set (inject from pipeline secret manager)." >&2
      exit 1
    fi
  done

  pipeline_run "az login --service-principal --username \"\$ARM_CLIENT_ID\" --password \"\$ARM_CLIENT_SECRET\" --tenant \"\$ARM_TENANT_ID\""
  pipeline_run "az account set --subscription \"\$ARM_SUBSCRIPTION_ID\""
  pipeline_run "az aks get-credentials --resource-group \"$resource_group\" --name \"$cluster_name\" --overwrite-existing"
}

pipeline_kube_smoke() {
  pipeline_run "kubectl get ns >/dev/null"
}
