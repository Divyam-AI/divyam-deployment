#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# deploy-ledger.sh — shared WRITER for the helm deploy ledger (~/.k8s-deploys/).
#
# Records every `make k8s -- install/upgrade`: one JSONL line per state transition (running →
# applied/failed) PLUS a per-attempt snapshot of the *input* artifacts.yaml. This lets a client (the
# `box` CLI's `box stack -d`) answer "what's deployed / is a deploy pending / did the last one fail"
# by COMPARING the last applied snapshot to the live artifacts.yaml — WITHOUT querying the cluster.
#
# Layout:
#   ~/.k8s-deploys/ledger.jsonl          append-only; last record per attempt wins
#   ~/.k8s-deploys/<attempt>/artifacts.yaml   the artifacts fed to that deploy, saved verbatim
#
# JSONL line (one object per line, plain — anyone can parse it):
#   {"ts":<epoch>,"attempt":"<id>","verb":"install|upgrade","scope":"<chart|all>",
#    "env":"<env>","state":"running|applied|failed"}
# `attempt` doubles as the snapshot subdir name. `scope` is the bare chart for `-l <chart>`, else "all".
#
# Best-effort throughout: a ledger/snapshot failure must NEVER fail the deploy (mirrors
# status-ledger.sh). READ via the box CLI; tools must not hand-parse beyond the documented schema.

DEPLOY_LEDGER_DIR="${DEPLOY_LEDGER_DIR:-$HOME/.k8s-deploys}"

# Epoch with a millisecond-ish suffix is overkill; a UTC second-resolution id is unique enough per
# deploy and sorts lexically == chronologically.
deploy_attempt_id() { date -u +%Y%m%dT%H%M%SZ; }

_deploy_jsonl() {  # <id> <verb> <scope> <env> <state>
  local id="$1" verb="$2" scope="$3" env="$4" state="$5"
  mkdir -p "$DEPLOY_LEDGER_DIR" 2>/dev/null || return 0
  printf '{"ts":%s,"attempt":"%s","verb":"%s","scope":"%s","env":"%s","state":"%s"}\n' \
    "$(date +%s)" "$id" "$verb" "$scope" "$env" "$state" \
    >> "$DEPLOY_LEDGER_DIR/ledger.jsonl" 2>/dev/null || true
}

deploy_record_start() {  # <artifacts_file> <verb> <scope> <env> -> echoes the attempt id
  local af="$1" verb="$2" scope="$3" env="$4"
  local id; id="$(deploy_attempt_id)"
  local dir="$DEPLOY_LEDGER_DIR/$id"
  if mkdir -p "$dir" 2>/dev/null; then
    [[ -f "$af" ]] && cp "$af" "$dir/artifacts.yaml" 2>/dev/null || true
  fi
  _deploy_jsonl "$id" "$verb" "$scope" "$env" running
  echo "$id"
}

deploy_record_end() {  # <attempt_id> <verb> <scope> <env> <state>
  _deploy_jsonl "$1" "$2" "$3" "$4" "$5"
}
