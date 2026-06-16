#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# bringup.sh — end-to-end bringup orchestrator (Phase 1 IaC + Phase 2 Helm) for this repo.
#
# Runs the documented from-scratch sequence as ONE hook and keeps a per-(cloud,env) step ledger so
# callers (CI, the sandbox bastion, humans) can query progress without re-deriving it. Every step
# shells out to the phase CLIs (scripts/iac.sh / scripts/k8s.sh) — no phase logic is duplicated here.
#
#   0-foundation -> 1-platform -> 2-app -> kubeconfig (+ reachability smoke) -> k8s-install
#
# Usage:
#   scripts/bringup.sh <command> [options]
#
# Commands:
#   run               Apply all IaC layers, fetch the cluster kubeconfig, smoke-test reachability
#                     (kubectl get ns — fail-closed before helm touches a cluster), then install
#                     the Helm stack. Resets the ledger, pre-seeds the full plan as `pending`,
#                     and rewrites it step by step as it goes.
#   status            Report per-step state from the ledger as a table — delegates to the
#                     standalone reader scripts/status.sh (same flags; kept here for back-compat).
#                     Exit codes: 0 = all steps applied; 1 = a step failed, running or pending
#                     (bringup in flight or died mid-way); 2 = never run (no ledger for cloud/env).
#                     `-w/--watch` re-renders every `-i <sec>` (default 30) until interrupted.
#   help              This help
#
# Options:
#   -c, --cloud <gcp|azure>        Cloud provider. Falls back to $CLOUD_PROVIDER, then .iac.conf.
#   -e, --env <name>               Environment. Falls back to $ENV, then .iac.conf.
#   -d, --values-dir <dir>         Helm values dir for the install (k8s.sh -d). Default k8s/helm-values.
#   -C, --channel <stable|nightly> Artifacts channel for the install (k8s.sh -C).
#   -a, --artifacts-version <v>    Artifacts version for the install (k8s.sh -a).
#       --porcelain                status: machine-readable `<step>=<state>` lines only (stable
#                                  contract for tools; timestamps stripped).
#   -w, --watch                    status: re-render continuously (clear + table).
#   -i, --interval <sec>           status watch refresh interval (default 30).
#   -y, --yes                      Skip confirmation prompts (automation).
#   -n, --dry-run                  Print the underlying commands (threads -n to iac.sh/k8s.sh);
#                                  the ledger is not touched.
#   -h, --help                     Help.
#
# Ledger: .bringup-status.<cloud>.<env> at the repo root (gitignored). WRITTEN via the shared
# scripts/status-ledger.sh (also sourced by iac.sh/k8s.sh, which stamp their own module-level
# steps); READ by scripts/status.sh — external tools must ask `make status` / `status --porcelain`
# instead of reading the file.
#
# Examples:
#   scripts/bringup.sh run -c azure -e sandbox -d k8s/helm-values -y
#   scripts/bringup.sh run -n                       # preview the full sequence
#   scripts/bringup.sh status                       # progress table (also: make status)
#   scripts/bringup.sh status -w -i 30              # live progress, refresh every 30s
#   scripts/bringup.sh status --porcelain           # <step>=<state> lines, exit code = health
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"
CONF="$REPO_ROOT/.iac.conf"
# shellcheck source=scripts/lib/cli.sh
source "$SCRIPTS/lib/cli.sh"

STEPS=(0-foundation 1-platform 2-app kubeconfig k8s-install)

# --- arg parsing (mirrors iac.sh/k8s.sh) -----------------------------------
SUBCMD=""; CLI_CLOUD=""; CLI_ENV=""; VALUES_DIR=""; CHANNEL=""; ART_VERSION=""
ASSUME_YES=0; DRYRUN=0; PORCELAIN=0; WATCH=0; INTERVAL=30
usage() { cli::usage "$0"; }
die() { cli::die "$@"; }   # ❌-prefixed to stderr, exit 2 (shared lib; preserves prior exit code)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--cloud)       CLI_CLOUD="${2:?--cloud needs a value}"; shift 2;;
    --cloud=*)        CLI_CLOUD="${1#*=}"; shift;;
    -e|--env)         CLI_ENV="${2:?--env needs a value}"; shift 2;;
    --env=*)          CLI_ENV="${1#*=}"; shift;;
    -d|--values-dir)  VALUES_DIR="${2:?--values-dir needs a value}"; shift 2;;
    --values-dir=*)   VALUES_DIR="${1#*=}"; shift;;
    -C|--channel)     CHANNEL="${2:?--channel needs a value}"; shift 2;;
    --channel=*)      CHANNEL="${1#*=}"; shift;;
    -a|--artifacts-version) ART_VERSION="${2:?--artifacts-version needs a value}"; shift 2;;
    --artifacts-version=*)  ART_VERSION="${1#*=}"; shift;;
    --porcelain)      PORCELAIN=1; shift;;
    -w|--watch)       WATCH=1; shift;;
    -i|--interval)    INTERVAL="${2:?--interval needs a value}"; shift 2;;
    --interval=*)     INTERVAL="${1#*=}"; shift;;
    -y|--yes)         ASSUME_YES=1; shift;;
    -n|--dry-run)     DRYRUN=1; shift;;
    -h|--help)        usage; exit 0;;
    -*)               die "unknown option: $1 (try --help)";;
    *)                if [[ -z "$SUBCMD" ]]; then SUBCMD="$1"; else die "unexpected arg: $1"; fi; shift;;
  esac
done
[[ -n "$SUBCMD" ]] || { usage; exit 0; }

# --- resolve cloud/env: CLI flag > shell env > .iac.conf (same order as iac.sh) ---
CONF_CLOUD=""; CONF_ENV=""
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
fi
CLOUD="${CLI_CLOUD:-${CLOUD_PROVIDER:-${CONF_CLOUD:-}}}"
ENV_NAME="${CLI_ENV:-${ENV:-${CONF_ENV:-}}}"
[[ -n "$CLOUD" && -n "$ENV_NAME" ]] || die "cloud/env unknown — pass -c/-e or set them via 'iac.sh config'"

LEDGER="$REPO_ROOT/.bringup-status.${CLOUD}.${ENV_NAME}"

# --- ledger helpers (run only; status reads, never writes) ------------------
# Line format: <step>=<state>@<epoch>  (last line per step wins; `running` is stamped at step start
# so status can show in-flight progress and elapsed time). The writer is shared with iac.sh/k8s.sh
# (scripts/status-ledger.sh) so lower-level full-layer/install runs keep the same ledger live.
# shellcheck disable=SC1091
source "$SCRIPTS/status-ledger.sh"
STEP=""
begin() {
  STEP="$1"; echo "== bringup: ${STEP} (cloud=${CLOUD}, env=${ENV_NAME}) =="
  [[ "$DRYRUN" -eq 1 ]] || ledger_stamp "$REPO_ROOT" "$CLOUD" "$ENV_NAME" "$STEP" running
}
done_step() { [[ "$DRYRUN" -eq 1 ]] || ledger_stamp "$REPO_ROOT" "$CLOUD" "$ENV_NAME" "$STEP" applied; STEP=""; }
stamp_fail() { [[ "$DRYRUN" -eq 1 || -z "$STEP" ]] || ledger_stamp "$REPO_ROOT" "$CLOUD" "$ENV_NAME" "$STEP" failed; }

# --- commands ----------------------------------------------------------------
cmd_run() {
  local -a yn=()
  [[ "$ASSUME_YES" -eq 1 ]] && yn+=(-y)
  [[ "$DRYRUN" -eq 1 ]] && yn+=(-n)
  local -a k8s_install_args=(-d "${VALUES_DIR:-k8s/helm-values}" -e "$ENV_NAME")
  [[ -n "$CHANNEL" ]] && k8s_install_args+=(-C "$CHANNEL")
  [[ -n "$ART_VERSION" ]] && k8s_install_args+=(-a "$ART_VERSION")

  if [[ "$DRYRUN" -ne 1 ]]; then
    : > "$LEDGER"
    # Pre-seed the full plan as `pending` so `make status` shows what's left from minute one.
    local s; for s in "${STEPS[@]}"; do ledger_stamp "$REPO_ROOT" "$CLOUD" "$ENV_NAME" "$s" pending; done
  fi
  trap stamp_fail EXIT

  for layer in 0-foundation 1-platform 2-app; do
    begin "$layer"
    "$SCRIPTS/iac.sh" apply -l "$layer" -c "$CLOUD" -e "$ENV_NAME" "${yn[@]}"
    done_step
  done

  begin kubeconfig
  "$SCRIPTS/k8s.sh" kubeconfig -c "$CLOUD" -e "$ENV_NAME" "${yn[@]}"
  if [[ "$DRYRUN" -ne 1 ]]; then
    kubectl get ns >/dev/null \
      || cli::die "kubectl cannot reach the cluster with the fetched kubeconfig — refusing to run helm." 1
    echo "kubectl context: $(kubectl config current-context)"
  fi
  done_step

  begin k8s-install
  "$SCRIPTS/k8s.sh" install "${k8s_install_args[@]}" "${yn[@]}"
  done_step

  trap - EXIT
  echo "bringup complete (cloud=${CLOUD}, env=${ENV_NAME}). Inspect any time: scripts/bringup.sh status"
}

# status rendering lives in the standalone reader scripts/status.sh (one READER for the ledger,
# shared by `make status`, this back-compat hook, and any external caller).
cmd_status() {
  local -a args=(-c "$CLOUD" -e "$ENV_NAME" -i "$INTERVAL")
  if [[ "$PORCELAIN" -eq 1 ]]; then args+=(--porcelain); fi
  if [[ "$WATCH" -eq 1 ]]; then args+=(-w); fi
  exec "$SCRIPTS/status.sh" "${args[@]}"
}

case "$SUBCMD" in
  run)    cmd_run;;
  status) cmd_status;;
  help)   usage;;
  *)      die "unknown command: $SUBCMD (try --help)";;
esac
