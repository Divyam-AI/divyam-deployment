#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# k8s-diagnose.sh — capture a structured "why did the deploy fail" artifact from a live cluster.
#
# Invoked by `scripts/k8s.sh diagnose` (and reusable directly). Snapshots the failing helm releases
# and unhealthy pods into a self-contained bundle + a machine-readable summary.json, derives a
# best-effort verdict, and redacts secret-shaped strings. Read-only against the cluster; ALWAYS
# exits 0 (it is a reporter, not a gate) so it never changes a caller's exit code.
#
# Consumers: a human (`make k8s -- diagnose`), the divyam-sandbox `box` CLI (pulls the bundle to the
# laptop + enriches it with component/repo/ref), and the nightly CI pipeline (ships it as an
# artifact). The summary.json schema is the shared contract — see SCHEMA below.
#
# Portability: needs only helm + kubectl + jq (already required wherever helmfile deploys), NOT
# python — so any client deploying the stack can run it.
#
# Usage: k8s-diagnose.sh --out-dir <dir> [--release <chart>] [--env <name>] [--command "<str>"]
#                        [--exit-code <n>] [--error-log <file>]
#   --release/--env  scope to one release (name=<chart>-<env>); omit to scan the whole stack.
#   --command/--exit-code/--error-log  context from the failed `make k8s -- upgrade` (recorded in
#                        summary.json .helm; --error-log's tail feeds the HELM_RENDER/TIMEOUT rules).
set -uo pipefail   # NOT -e: a diagnostic must keep going past individual probe failures.

OUT_DIR=""; REL_CHART=""; ENV_NAME=""; HELM_CMD=""; HELM_RC=""; ERROR_LOG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)    OUT_DIR="${2:?}"; shift 2;;
    --release)    REL_CHART="${2:-}"; shift 2;;
    --env)        ENV_NAME="${2:-}"; shift 2;;
    --command)    HELM_CMD="${2:-}"; shift 2;;
    --exit-code)  HELM_RC="${2:-}"; shift 2;;
    --error-log)  ERROR_LOG="${2:-}"; shift 2;;
    *) echo "k8s-diagnose: ignoring unknown arg: $1" >&2; shift;;
  esac
done
[[ -n "$OUT_DIR" ]] || { echo "k8s-diagnose: --out-dir is required" >&2; exit 0; }

have() { command -v "$1" >/dev/null 2>&1; }
if ! have kubectl || ! have helm || ! have jq; then
  echo "k8s-diagnose: need kubectl + helm + jq on PATH; skipping capture" >&2
  exit 0
fi

mkdir -p "$OUT_DIR/releases" "$OUT_DIR/workloads" "$OUT_DIR/pods" "$OUT_DIR/events" 2>/dev/null || true
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- redaction: mask secret-shaped values in captured text -------------------------------------
# Best-effort, conservative: values of env/keys whose name screams secret, plus long base64/hex
# blobs and bearer tokens. Operates on stdin -> stdout. Mirrors the intent of ci_deploy's redactor
# (the python side reuses that util; this is the bash-only deploy path which can't import it).
redact() {
  sed -E \
    -e 's/((PASS|PASSWORD|SECRET|TOKEN|APIKEY|API_KEY|ACCESS_KEY|PRIVATE_KEY|CREDENTIAL|AUTH)[A-Z0-9_]*["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?)[^[:space:]"'"'"']+/\1***REDACTED***/Ig' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._-]+/\1***REDACTED***/Ig' \
    -e 's/([A-Za-z0-9+\/]{40,}={0,2})/***REDACTED***/g'
}
# Write stdin to a file, redacted. Usage: <cmd> | save <relpath>
save() { redact > "$OUT_DIR/$1" 2>/dev/null || true; }

# --- 1) helm releases: failing ones (or the targeted one) --------------------------------------
ALL_REL="$(helm list -A -o json 2>/dev/null || echo '[]')"
TARGET_REL=""; [[ -n "$REL_CHART" && -n "$ENV_NAME" ]] && TARGET_REL="${REL_CHART}-${ENV_NAME}"

# A release is "failing" if status != deployed, OR it is the explicitly targeted release.
FAILING_REL="$(printf '%s' "$ALL_REL" | jq -c --arg t "$TARGET_REL" \
  '[ .[] | select((.status != "deployed") or (.name == $t)) ]' 2>/dev/null || echo '[]')"

# Namespaces to inspect: the failing releases' namespaces (+ scan-all when nothing targeted).
declare -a NSES=()
while IFS= read -r ns; do [[ -n "$ns" ]] && NSES+=("$ns"); done < <(printf '%s' "$FAILING_REL" | jq -r '.[].namespace' 2>/dev/null | sort -u)

# Capture helm status/history for each failing release.
while IFS=$'\t' read -r rname rns; do
  [[ -z "$rname" ]] && continue
  helm status "$rname" -n "$rns" 2>&1 | save "releases/${rns}__${rname}.status.txt"
  helm history "$rname" -n "$rns" 2>&1 | save "releases/${rns}__${rname}.history.txt"
done < <(printf '%s' "$FAILING_REL" | jq -r '.[] | [.name,.namespace] | @tsv' 2>/dev/null)

# --- 2) pods: unhealthy ones in the relevant namespaces ----------------------------------------
# Pull pod json for the target namespaces (or all if none resolved), then keep the unhealthy ones:
# not Running/Succeeded phase, OR a container not ready / waiting with a reason / terminated nonzero.
if [[ "${#NSES[@]}" -gt 0 ]]; then
  PODS_JSON='{"items":[]}'
  for ns in "${NSES[@]}"; do
    one="$(kubectl get pods -n "$ns" -o json 2>/dev/null || echo '{"items":[]}')"
    PODS_JSON="$(jq -s '{items: (.[0].items + .[1].items)}' <(printf '%s' "$PODS_JSON") <(printf '%s' "$one") 2>/dev/null || printf '%s' "$PODS_JSON")"
  done
else
  PODS_JSON="$(kubectl get pods -A -o json 2>/dev/null || echo '{"items":[]}')"
fi

UNHEALTHY="$(printf '%s' "$PODS_JSON" | jq -c '
  [ .items[]
    | select(
        (.status.phase != "Running" and .status.phase != "Succeeded")
        or ([ (.status.containerStatuses // [])[] | select(.ready != true) ] | length > 0)
        or ([ (.status.containerStatuses // [])[] | select((.restartCount // 0) > 0) ] | length > 0)
      )
    | {
        name: .metadata.name,
        namespace: .metadata.namespace,
        phase: .status.phase,
        ready: ([ (.status.containerStatuses // [])[] | .ready ] | all),
        restarts: ([ (.status.containerStatuses // [])[] | (.restartCount // 0) ] | add // 0),
        containers: [ (.status.containerStatuses // [])[] | {
            name: .name,
            image: .image,
            ready: .ready,
            state: (.state | keys[0] // "unknown"),
            reason: (.state.waiting.reason // .state.terminated.reason // null),
            message: (.state.waiting.message // .state.terminated.message // null),
            last_terminated: (if .lastState.terminated then
                {reason: .lastState.terminated.reason, exit_code: .lastState.terminated.exitCode}
              else null end)
          } ]
      }
  ]' 2>/dev/null || echo '[]')"

# Per-pod evidence files (describe / logs / previous logs), all redacted.
while IFS=$'\t' read -r pns pname; do
  [[ -z "$pname" ]] && continue
  kubectl describe pod "$pname" -n "$pns" 2>&1 | save "pods/${pns}__${pname}.describe.txt"
  kubectl logs "$pname" -n "$pns" --all-containers --tail=200 2>&1 | save "pods/${pns}__${pname}.logs.txt"
  kubectl logs "$pname" -n "$pns" --all-containers --previous --tail=200 2>/dev/null | save "pods/${pns}__${pname}.logs-previous.txt"
done < <(printf '%s' "$UNHEALTHY" | jq -r '.[] | [.namespace,.name] | @tsv' 2>/dev/null)

# Attach a short event list + log tail to each pod record (for summary.json), and dump full events.
for ns in "${NSES[@]:-}"; do
  [[ -z "$ns" ]] && continue
  kubectl get events -n "$ns" --sort-by=.lastTimestamp 2>&1 | save "events/${ns}.events.txt"
done

enrich_pod() {  # adds events[] + log_tail + log_previous + files{} to one pod json record
  local rec="$1" pns pname ev lt lp
  pns="$(printf '%s' "$rec" | jq -r '.namespace')"
  pname="$(printf '%s' "$rec" | jq -r '.name')"
  ev="$(kubectl get events -n "$pns" --field-selector "involvedObject.name=$pname" \
        --sort-by=.lastTimestamp -o json 2>/dev/null \
        | jq -c '[ .items[] | "\(.reason): \(.message)" ] | .[-8:]' 2>/dev/null || echo '[]')"
  lt="$(tail -c 4000 "$OUT_DIR/pods/${pns}__${pname}.logs.txt" 2>/dev/null | jq -Rs . 2>/dev/null || echo '""')"
  lp="$(tail -c 4000 "$OUT_DIR/pods/${pns}__${pname}.logs-previous.txt" 2>/dev/null | jq -Rs . 2>/dev/null || echo '""')"
  printf '%s' "$rec" | jq -c \
    --argjson ev "$ev" --argjson lt "$lt" --argjson lp "$lp" \
    --arg dsc "pods/${pns}__${pname}.describe.txt" --arg lg "pods/${pns}__${pname}.logs.txt" \
    '. + {events: $ev, log_tail: $lt, log_previous: $lp, files: {describe: $dsc, logs: $lg}}' 2>/dev/null \
    || printf '%s' "$rec"
}
ENRICHED="[]"
while IFS= read -r rec; do
  [[ -z "$rec" || "$rec" == "null" ]] && continue
  one="$(enrich_pod "$rec")"
  ENRICHED="$(jq -c --argjson o "$one" '. + [$o]' <(printf '%s' "$ENRICHED") 2>/dev/null || printf '%s' "$ENRICHED")"
done < <(printf '%s' "$UNHEALTHY" | jq -c '.[]' 2>/dev/null)

# --- 3) workloads: rollout conditions for the relevant namespaces ------------------------------
WORKLOADS="[]"
for ns in "${NSES[@]:-}"; do
  [[ -z "$ns" ]] && continue
  w="$(kubectl get deploy,statefulset,job -n "$ns" -o json 2>/dev/null \
    | jq -c --arg ns "$ns" '[ .items[]
        | { kind: .kind, name: .metadata.name, namespace: $ns,
            ready: (((.status.readyReplicas // .status.ready // 0) | tostring) + "/" + ((.spec.replicas // 1) | tostring)),
            conditions: [ (.status.conditions // [])[] | select(.status != "True") | {type: .type, reason: (.reason // ""), message: (.message // "")} ] }
        | select(.conditions | length > 0) ]' 2>/dev/null || echo '[]')"
  WORKLOADS="$(jq -c -s 'add' <(printf '%s' "$WORKLOADS") <(printf '%s' "$w") 2>/dev/null || printf '%s' "$WORKLOADS")"
  kubectl get deploy,statefulset,job -n "$ns" -o wide 2>&1 | save "workloads/${ns}.txt"
done

# --- 4) error tail from the failed upgrade -----------------------------------------------------
ERR_TAIL=""
[[ -n "$ERROR_LOG" && -f "$ERROR_LOG" ]] && ERR_TAIL="$(tail -n 40 "$ERROR_LOG" 2>/dev/null | redact)"

# --- 5) verdict cascade (first match wins; order = severity) -----------------------------------
# Reads the enriched pods + error tail. Pure field/string matching — every verdict is traceable.
N_PODS="$(printf '%s' "$ENRICHED" | jq 'length' 2>/dev/null || echo 0)"
reasons() { printf '%s' "$ENRICHED" | jq -r '.[].containers[].reason // empty' 2>/dev/null; }
match_reason() { reasons | grep -qiE "$1"; }
ev_match()    { printf '%s' "$ENRICHED" | jq -r '.[].events[]? // empty' 2>/dev/null | grep -qiE "$1"; }
err_match()   { printf '%s' "$ERR_TAIL" | grep -qiE "$1"; }

CLASS="UNKNOWN"; ROOT=""
first_pod_with() {  # echo "<pod>\t<ns>\t<ctr>\t<reason>\t<exit>" for the first pod whose container reason matches $1
  printf '%s' "$ENRICHED" | jq -r --arg re "$1" '
    .[] as $p | $p.containers[] | select((.reason // "") | test($re;"i"))
    | [$p.name, $p.namespace, .name, (.reason // ""), ((.last_terminated.exit_code // "") | tostring)] | @tsv' 2>/dev/null | head -1
}

if err_match 'YAML parse|template:|admission webhook|denied the request|immutable|invalid value|failed to create|conversion' && [[ "$N_PODS" -eq 0 ]]; then
  CLASS="HELM_RENDER"
  ROOT="release render/apply failed: $(printf '%s' "$ERR_TAIL" | grep -iE 'error|denied|invalid|immutable' | head -1 | cut -c1-160)"
elif match_reason 'ImagePullBackOff|ErrImagePull|InvalidImageName'; then
  CLASS="IMAGE_PULL"
  IFS=$'\t' read -r p ns _ r _ < <(first_pod_with 'ImagePullBackOff|ErrImagePull|InvalidImageName')
  img="$(printf '%s' "$ENRICHED" | jq -r --arg p "$p" '.[] | select(.name==$p) | .containers[] | select(.reason|test("Image";"i")) | .image' 2>/dev/null | head -1)"
  ROOT="${p}: ${r} pulling ${img}"
elif match_reason 'CreateContainerConfigError|CreateContainerError|RunContainerError' || ev_match 'couldn.t find key|secret .* not found|configmap .* not found|not synced'; then
  CLASS="CONFIG_ERROR"
  IFS=$'\t' read -r p ns _ r _ < <(first_pod_with 'CreateContainerConfigError|CreateContainerError|RunContainerError')
  ROOT="${p:-a pod}: ${r:-config/secret error} — see pods/${ns}__${p}.describe.txt"
elif match_reason 'CrashLoopBackOff' || printf '%s' "$ENRICHED" | jq -e '[.[].containers[] | select((.last_terminated.exit_code // 0) != 0)] | length > 0' >/dev/null 2>&1; then
  CLASS="CRASH_LOOP"
  IFS=$'\t' read -r p ns c r ec < <(first_pod_with 'CrashLoopBackOff')
  [[ -z "$p" ]] && IFS=$'\t' read -r p ns c < <(printf '%s' "$ENRICHED" | jq -r '.[] as $p | $p.containers[] | select((.last_terminated.exit_code // 0) != 0) | [$p.name,$p.namespace,.name] | @tsv' 2>/dev/null | head -1)
  ROOT="${p}/${c}: CrashLoopBackOff${ec:+, last exit $ec} — see pods/${ns}__${p}.logs-previous.txt"
elif printf '%s' "$ENRICHED" | jq -e '[.[] | select(.phase=="Pending")] | length > 0' >/dev/null 2>&1 && ev_match 'FailedScheduling|Insufficient|didn.t match|untolerated taint|unbound|no nodes available'; then
  CLASS="SCHEDULING"
  p="$(printf '%s' "$ENRICHED" | jq -r '[.[] | select(.phase=="Pending")][0].name' 2>/dev/null)"
  why="$(printf '%s' "$ENRICHED" | jq -r '.[].events[]? // empty' 2>/dev/null | grep -iE 'FailedScheduling|Insufficient|untolerated|unbound' | head -1 | cut -c1-160)"
  ROOT="${p}: Pending — ${why}"
elif ev_match 'Readiness probe failed|Liveness probe failed|Unhealthy'; then
  CLASS="PROBE_FAILURE"
  p="$(printf '%s' "$ENRICHED" | jq -r '.[0].name' 2>/dev/null)"
  ROOT="${p}: readiness/liveness probe failing — see pods/ describe + logs"
elif err_match 'timed out waiting|context deadline exceeded|DeadlineExceeded'; then
  CLASS="TIMEOUT_UNKNOWN"
  ROOT="deploy timed out waiting for readiness; no clear pod-level cause captured"
fi
[[ -z "$ROOT" ]] && ROOT="deploy failed; ${N_PODS} unhealthy pod(s) captured — inspect the bundle"

# --- 6) assemble summary.json (the contract) ---------------------------------------------------
REL_SUMMARY="$(printf '%s' "$FAILING_REL" | jq -c '[ .[] | {name, namespace, status, revision: (.revision|tostring)} ]' 2>/dev/null || echo '[]')"
FAILED_RELEASE="$(printf '%s' "$FAILING_REL" | jq -r '.[0].name // ""' 2>/dev/null)"

jq -n \
  --arg ts "$TS" --arg env "$ENV_NAME" \
  --arg selector "${REL_CHART:-all}" \
  --arg class "$CLASS" --arg root "$ROOT" --arg failed_release "$FAILED_RELEASE" \
  --arg cmd "$HELM_CMD" --arg rc "$HELM_RC" --arg errtail "$ERR_TAIL" \
  --argjson releases "$REL_SUMMARY" \
  --argjson workloads "$WORKLOADS" \
  --argjson pods "$ENRICHED" \
  --arg bundle "$OUT_DIR" \
  '{
    schema_version: 1,
    timestamp: $ts,
    stage: "deploy",
    trigger: "failure",
    env: $env,
    selector: $selector,
    verdict: { classification: $class, root_cause: $root, failed_release: $failed_release },
    helm: { command: $cmd, exit_code: ($rc | tonumber? // null), error_tail: $errtail, releases: $releases },
    workloads: $workloads,
    pods: $pods,
    bundle_dir: $bundle
  }' > "$OUT_DIR/summary.json" 2>/dev/null \
  || echo '{"schema_version":1,"stage":"deploy","verdict":{"classification":"UNKNOWN","root_cause":"summary assembly failed; see bundle files"}}' > "$OUT_DIR/summary.json"

echo "k8s-diagnose: ${CLASS} — ${ROOT}"
echo "k8s-diagnose: bundle written to ${OUT_DIR} (summary.json + releases/ pods/ workloads/ events/)"
exit 0
