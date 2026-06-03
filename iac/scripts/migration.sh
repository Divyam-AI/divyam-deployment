#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Observability refactor — Terraform state migration (1-k8s → 2-monitoring)
#
# Moves resources that were relocated in code from:
#   - 1-platform/1-k8s/azure          → 1-platform/2-monitoring/native/azure
#   - 1-platform/1-k8s/gcp            → 1-platform/2-monitoring/native/gcp
#
# Run this ONCE per environment (per VALUES_FILE / remote state prefix) after
# pulling the observability refactor and BEFORE the first `terragrunt apply` on
# 2-monitoring that would recreate AMW/Grafana/log bucket.
#
# How to run
# ----------
#   cd divyam-deployment/iac
#
#   # Required — must match the env you originally applied 1-k8s with:
#   export CLOUD_PROVIDER=azure          # or gcp
#   export VALUES_FILE=values/divyam-pre-prod-defaults.hcl
#   export ARM_CLIENT_ID=...             # Azure only
#   export ARM_CLIENT_SECRET=...
#   export ARM_SUBSCRIPTION_ID=...
#   export ARM_TENANT_ID=...
#   # GCP: gcloud auth application-default login
#
#   # Optional:
#   export DRY_RUN=1                     # print commands only
#   export SKIP_GCP=1                    # Azure-only migration
#   export SKIP_AZURE=1                  # GCP-only migration
#
#   ./scripts/migration.sh
#
# What it does
# ------------
#   1. terragrunt init in source and destination modules
#   2. terragrunt state pull → local temp state files
#   3. tofu state mv (cross-state) for each relocated resource address
#   4. terragrunt state push updated state back to remote/local backend
#   5. Prints verification commands
#
# If a resource was never created (e.g. metrics disabled), state mv will error —
# that line can be skipped safely.
#
# After migration
# ---------------
#   cd 1-platform
#   terragrunt run plan --all --filter "./**/2-monitoring/**/${CLOUD_PROVIDER}"
#   terragrunt run plan --all --filter "./**/1-k8s/${CLOUD_PROVIDER}"
#   # Expect no "will be created" for moved resources in 2-monitoring; k8s plan
#   # may show monitor_metrics removal on AKS (in-place cluster update).
#
# Alternative: import (only if state was lost)
# --------------------------------------------
#   If resources exist in Azure/GCP but are absent from both state files, use
#   `terragrunt import` from the NEW module directory. Example (Azure AMW):
#     cd 1-platform/2-monitoring/native/azure
#     terragrunt import 'azurerm_monitor_workspace.prometheus["enabled"]' \
#       '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Monitor/accounts/<amw-name>'
#   Discover IDs: Azure Portal, or `az monitor account show`, or old state backup.
#------------------------------------------------------------------------------

set -euo pipefail

IAC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN="${DRY_RUN:-0}"
CLOUD_PROVIDER="${CLOUD_PROVIDER:-}"
VALUES_FILE="${VALUES_FILE:-values/defaults.hcl}"

if [[ -z "$CLOUD_PROVIDER" ]]; then
  echo "ERROR: Set CLOUD_PROVIDER=azure or CLOUD_PROVIDER=gcp" >&2
  exit 1
fi

export VALUES_FILE
export CLOUD_PROVIDER

K8S_MODULE="${IAC_ROOT}/1-platform/1-k8s/${CLOUD_PROVIDER}"
MON_MODULE="${IAC_ROOT}/1-platform/2-monitoring/native/${CLOUD_PROVIDER}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

log() { echo "==> $*"; }
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

tg_init() {
  local dir="$1"
  log "terragrunt init: $dir"
  run bash -c "cd '$dir' && terragrunt init -reconfigure"
}

tg_pull() {
  local dir="$1" out="$2"
  log "state pull: $dir → $out"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] terragrunt state pull > $out  (in $dir)"
    touch "$out"
  else
    bash -c "cd '$dir' && terragrunt state pull" >"$out"
  fi
}

tg_push() {
  local dir="$1" state="$2"
  log "state push: $state → $dir"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] terragrunt state push $state  (in $dir)"
  else
    bash -c "cd '$dir' && terragrunt state push '$state'"
  fi
}

state_mv() {
  local src_state="$1" dst_state="$2" addr="$3"
  log "state mv: $addr"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] tofu state mv -state=$src_state -state-out=$dst_state '$addr' '$addr'"
  else
    tofu state mv -state="$src_state" -state-out="$dst_state" "$addr" "$addr"
  fi
}

migrate_azure() {
  log "Azure: migrate metrics stack from 1-k8s/azure → 2-monitoring/native/azure"

  local src="${WORKDIR}/k8s-azure.tfstate"
  local dst="${WORKDIR}/monitoring-azure.tfstate"
  local dst_working="${WORKDIR}/monitoring-azure-working.tfstate"

  tg_init "$K8S_MODULE"
  tg_init "$MON_MODULE"

  tg_pull "$K8S_MODULE" "$src"
  tg_pull "$MON_MODULE" "$dst"
  cp "$dst" "$dst_working"

  # Order: workspace → DCR → association → Grafana → role assignment
  local resources=(
    'azurerm_monitor_workspace.prometheus["enabled"]'
    'azurerm_monitor_data_collection_rule.aks_prometheus["enabled"]'
    'azurerm_monitor_data_collection_rule_association.aks_assoc["enabled"]'
    'azurerm_dashboard_grafana.grafana["enabled"]'
    'azurerm_role_assignment.grafana_reader["enabled"]'
  )

  for addr in "${resources[@]}"; do
    if [[ "$DRY_RUN" != "1" ]]; then
      if ! tofu state list -state="$src" 2>/dev/null | grep -Fxq "$addr"; then
        echo "    skip (not in source state): $addr"
        continue
      fi
    fi
    state_mv "$src" "$dst_working" "$addr"
  done

  tg_push "$K8S_MODULE" "$src"
  tg_push "$MON_MODULE" "$dst_working"

  log "Azure migration done."
}

migrate_gcp() {
  log "GCP: migrate log bucket from 1-k8s/gcp → 2-monitoring/native/gcp"
  log "      (GKE logging/GMP: import cluster into 2-monitoring after first 1-k8s apply — see Verification)"

  local src="${WORKDIR}/k8s-gcp.tfstate"
  local dst="${WORKDIR}/monitoring-gcp.tfstate"
  local dst_working="${WORKDIR}/monitoring-gcp-working.tfstate"

  tg_init "$K8S_MODULE"
  tg_init "$MON_MODULE"

  tg_pull "$K8S_MODULE" "$src"
  tg_pull "$MON_MODULE" "$dst"
  cp "$dst" "$dst_working"

  local addr='google_logging_project_bucket_config.default_bucket[0]'
  if [[ "$DRY_RUN" != "1" ]]; then
    if ! tofu state list -state="$src" 2>/dev/null | grep -Fxq "$addr"; then
      echo "    skip (not in source state): $addr"
    else
      state_mv "$src" "$dst_working" "$addr"
    fi
  else
    state_mv "$src" "$dst_working" "$addr"
  fi

  tg_push "$K8S_MODULE" "$src"
  tg_push "$MON_MODULE" "$dst_working"

  log "GCP migration done."
}

log "IAC_ROOT=$IAC_ROOT"
log "CLOUD_PROVIDER=$CLOUD_PROVIDER VALUES_FILE=$VALUES_FILE DRY_RUN=$DRY_RUN"

case "$CLOUD_PROVIDER" in
  azure)
  if [[ "${SKIP_AZURE:-0}" != "1" ]]; then
    migrate_azure
  fi
  ;;
  gcp)
  if [[ "${SKIP_GCP:-0}" != "1" ]]; then
    migrate_gcp
  fi
  ;;
  *)
  echo "Unsupported CLOUD_PROVIDER=$CLOUD_PROVIDER" >&2
  exit 1
  ;;
esac

cat <<'EOF'

Verification
------------
  cd iac/1-platform/2-monitoring/native/${CLOUD_PROVIDER}
  terragrunt plan

  cd iac/1-platform/1-k8s/${CLOUD_PROVIDER}
  terragrunt plan

  cd iac/2-app/2-alerts/${CLOUD_PROVIDER}/prometheus   # or gcp/alerts/prometheus
  terragrunt plan

Import fallback (resource exists in cloud, missing from state)
--------------------------------------------------------------
  Azure AMW:
    terragrunt import 'azurerm_monitor_workspace.prometheus["enabled"]' \
      '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Monitor/accounts/<name>'

  Azure Grafana:
    terragrunt import 'azurerm_dashboard_grafana.grafana["enabled"]' \
      '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Dashboard/grafana/<name>'

  GCP log bucket (project-level):
    terragrunt import 'google_logging_project_bucket_config.default_bucket[0]' \
      'projects/<project-id>/locations/global/buckets/_Default'

  GKE observability (logging/GMP — run once per cluster after pulling this refactor):
    cd 1-platform/2-monitoring/native/gcp
    terragrunt import 'google_container_cluster.observability[0]' \
      'projects/<project-id>/locations/<region>/clusters/<cluster-name>'

EOF

echo "Migration script finished."
