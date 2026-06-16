#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# status-ledger.sh — shared WRITER for the bringup step ledger (.bringup-status.<cloud>.<env>).
# Sourced by bringup.sh, iac.sh and k8s.sh so `make status` reflects step progress no matter which
# entrypoint ran the step — the bringup hook OR the lower-level phase CLIs (full-layer apply/destroy,
# kubeconfig, install). Line format: <step>=<state>@<epoch>; last line per step wins.
# READ via `bringup.sh status` / `make status` — tools must never parse this file directly.
ledger_stamp() {  # <repo_root> <cloud> <env> <step> <state>
  local _root="$1" _cloud="$2" _env="$3" _step="$4" _state="$5"
  [[ -n "$_root" && -n "$_cloud" && -n "$_env" && -n "$_step" && -n "$_state" ]] || return 0
  echo "${_step}=${_state}@$(date +%s)" >> "${_root}/.bringup-status.${_cloud}.${_env}" 2>/dev/null || true
}
