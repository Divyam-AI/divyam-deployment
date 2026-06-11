#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# status.sh — standalone READER for the bringup step ledger (.bringup-status.<cloud>.<env>).
#
# Counterpart of scripts/status-ledger.sh (the shared WRITER, sourced by bringup.sh / iac.sh /
# k8s.sh). Renders whatever steps the ledger contains, in first-seen (execution) order:
# `bringup.sh run` pre-seeds its canonical plan as `pending`, and any module-level run stamps its
# own step (e.g. `iac.sh apply -l 1-platform.2-monitoring`, `k8s.sh install`), so the table shows
# module-granular progress no matter which entrypoint did the work. Reads the ledger only — no
# cloud calls, no terragrunt. `bringup.sh status` delegates here (back-compat).
#
# Usage:
#   scripts/status.sh [-c <gcp|azure>] [-e <env>] [--porcelain] [-w] [-i <sec>]
#
# Options:
#   -c, --cloud <gcp|azure>   Cloud provider. Falls back to $CLOUD_PROVIDER, then .iac.conf.
#   -e, --env <name>          Environment. Falls back to $ENV, then .iac.conf.
#       --porcelain           Machine-readable `<step>=<state>` lines only (stable contract for
#                             tools; timestamps stripped).
#   -w, --watch               Re-render continuously (clear + table) until interrupted. For a
#                             human terminal only — never run it from an automation/tool shell
#                             (it loops forever); poll one-shot renders instead.
#   -i, --interval <sec>      Watch refresh interval (default 30).
#   -h, --help                Help.
#
# Exit codes: 0 = all steps applied; 1 = a step failed, running or pending (in flight or died
#             mid-way); 2 = never run (no ledger for cloud/env). Same contract as the old
#             `bringup.sh status`.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$REPO_ROOT/.iac.conf"

usage() { grep '^#' "$0" | grep -vE '^#(!|[[:space:]]*SPDX-)' | sed 's/^# \{0,1\}//'; }
die() { echo "status.sh: $*" >&2; exit 2; }

CLI_CLOUD=""; CLI_ENV=""; PORCELAIN=0; WATCH=0; INTERVAL=30
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--cloud)    CLI_CLOUD="${2:?--cloud needs a value}"; shift 2;;
    --cloud=*)     CLI_CLOUD="${1#*=}"; shift;;
    -e|--env)      CLI_ENV="${2:?--env needs a value}"; shift 2;;
    --env=*)       CLI_ENV="${1#*=}"; shift;;
    --porcelain)   PORCELAIN=1; shift;;
    -w|--watch)    WATCH=1; shift;;
    -i|--interval) INTERVAL="${2:?--interval needs a value}"; shift 2;;
    --interval=*)  INTERVAL="${1#*=}"; shift;;
    -h|--help)     usage; exit 0;;
    *)             die "unknown arg: $1 (try --help)";;
  esac
done

# CLI flag > shell env > .iac.conf (same order as iac.sh/bringup.sh).
CONF_CLOUD=""; CONF_ENV=""
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
fi
CLOUD="${CLI_CLOUD:-${CLOUD_PROVIDER:-${CONF_CLOUD:-}}}"
ENV_NAME="${CLI_ENV:-${ENV:-${CONF_ENV:-}}}"
[[ -n "$CLOUD" && -n "$ENV_NAME" ]] || die "cloud/env unknown — pass -c/-e or set them via 'iac.sh config'"

LEDGER="$REPO_ROOT/.bringup-status.${CLOUD}.${ENV_NAME}"

# Static "typical duration" hints for the canonical bringup steps (rough, from observed sandbox
# runs). Module-level steps get "-".
typical_for() {
  case "$1" in
    0-foundation) echo "~4m";; 1-platform) echo "~15m";; 2-app) echo "~12m";;
    kubeconfig) echo "<1m";; k8s-install) echo "~15m";; *) echo "-";;
  esac
}

fmt_hms() {  # seconds -> e.g. 12m34s
  local s="$1"
  if (( s >= 3600 )); then printf '%dh%02dm' "$((s/3600))" "$(( (s%3600)/60 ))"
  elif (( s >= 60 )); then printf '%dm%02ds' "$((s/60))" "$((s%60))"
  else printf '%ds' "$s"; fi
}

render_status() {  # prints table (or porcelain); returns 0/1/2 per the contract
  if [[ ! -f "$LEDGER" ]]; then
    [[ "$PORCELAIN" -eq 1 ]] || echo "bringup: never run for cloud=${CLOUD}, env=${ENV_NAME}"
    return 2
  fi
  local rc=0 now steps step raw state epoch start_epoch started elapsed helm_running=0
  now="$(date +%s)"
  # Steps in first-seen order: the pre-seeded plan first, then module-level extras as they ran.
  steps="$(cut -d= -f1 "$LEDGER" | awk '!seen[$0]++' || true)"
  if [[ "$PORCELAIN" -ne 1 ]]; then
    echo "bringup status (cloud=${CLOUD}, env=${ENV_NAME})  $(date '+%H:%M:%S')"
    printf '%-28s %-9s %-9s %-9s %s\n' "STEP" "STATUS" "STARTED" "ELAPSED" "TYPICAL"
  fi
  for step in $steps; do
    raw="$(grep -E "^${step}=" "$LEDGER" | tail -1 | cut -d= -f2 || true)"
    state="${raw%@*}"
    epoch=""; [[ "$raw" == *@* ]] && epoch="${raw#*@}"
    # Latest attempt's start: module re-runs append fresh `running` lines, old ones are history.
    start_epoch="$(grep -E "^${step}=running@" "$LEDGER" | tail -1 | cut -d@ -f2 || true)"
    if [[ "$PORCELAIN" -eq 1 ]]; then
      echo "${step}=${state:-missing}"
    else
      started="-"; elapsed="-"
      [[ -n "$start_epoch" ]] && started="$(date -d "@${start_epoch}" '+%H:%M:%S' 2>/dev/null || date -r "$start_epoch" '+%H:%M:%S')"
      if [[ -n "$start_epoch" ]]; then
        case "$state" in
          running) elapsed="$(fmt_hms $(( now - start_epoch )))";;
          applied|failed|destroyed) [[ -n "$epoch" ]] && (( epoch >= start_epoch )) && elapsed="$(fmt_hms $(( epoch - start_epoch )))";;
        esac
      fi
      printf '%-28s %-9s %-9s %-9s %s\n' "$step" "${state:-pending}" "$started" "$elapsed" "$(typical_for "$step")"
    fi
    [[ "${state:-}" == "applied" ]] || rc=1
    [[ "$step" == "k8s-install" && "${state:-}" == "running" ]] && helm_running=1
  done
  # The helm stage has richer live views of its own — point the human at them while it runs.
  if [[ "$helm_running" -eq 1 && "$PORCELAIN" -ne 1 ]]; then
    echo
    echo "helm stage in flight — live release detail:"
    echo "  make k8s -- status --tui   (terminal UI)  |  make k8s -- status --dashboard   (web UI)"
  fi
  return "$rc"
}

if [[ "$WATCH" -eq 1 ]]; then
  while true; do
    clear 2>/dev/null || true
    render_status || true
    sleep "$INTERVAL"
  done
fi
render_status
exit "$?"
