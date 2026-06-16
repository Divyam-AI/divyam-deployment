#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# k8s.sh — Phase-2 Helmfile workflow CLI for this repo.
#
# A single entrypoint over the documented Helmfile flow, with standard CLI args (short -x and
# long --xxx), a remembered values-dir/env, and a release selector passed through to helmfile.
# It maps everyday verbs (install/upgrade/delete) onto helmfile (sync/apply/destroy) and always
# prints the exact command it runs. Mirrors scripts/iac.sh. See CLAUDE.md "Phase 2" / helmfile-ops.
#
# Usage:
#   scripts/k8s.sh <command> [options]
#
# Commands:
#   config            Show or set the remembered values-dir/env/artifacts (persisted to .k8s.conf)
#   diff              helmfile diff (preview changes)
#   install           First install — helmfile sync (installs ALL releases). Auto-diffs first.
#   upgrade           Routine upgrade — helmfile apply (only changed). Auto-diffs first.
#   delete            Uninstall — helmfile destroy (type-to-confirm)
#   template          Render manifests locally (append `-- --debug` to pass flags to helm)
#   status            Show release state: `helm ls -A`, then optionally the TUI or web dashboard
#   kubeconfig        Authenticate to the cloud and (re)fetch cluster kubeconfig (alias: auth)
#   help              This help
#
# Options:
#   -l, --release <chart>   Target a single release -> `helmfile -l name=<chart>-<env>`.
#                           A value containing '=' (e.g. name=foo, tier=db) is passed as a raw label.
#                           Omit to target the whole stack.
#   -f, --filter <sel>      Raw helmfile selector override (-> `helmfile -l <sel>`).
#   -e, --env <name>        Environment. Falls back to $ENV, then .k8s.conf, then provider.yaml.
#   -d, --values-dir <dir>  Helm values dir (default k8s/helm-values). Falls back to $HELMFILE_VALUES_DIR / .k8s.conf.
#   -a, --artifacts-version <v>  Set ARTIFACTS_VERSION — a release id or "latest" (else $ARTIFACTS_VERSION
#                           / .k8s.conf / helmfile default). With -C, resolves within that channel.
#   -C, --channel <stable|nightly>  Set ARTIFACTS_CHANNEL -> releases/<channel>/<-a|latest>-artifacts.yaml.
#                           Omit to use a local artifacts.yaml or stable/latest. See k8s/releases/VERSIONING.md.
#       --tui                 status: open the helm-tui terminal UI (`helm tui`).
#       --dashboard           status: open the helm-dashboard web UI (`helm dashboard`).
#   kubeconfig options (resolved from iac/values/secrets.env + provider.yaml when omitted):
#   -c, --cloud <gcp|azure>      Cloud provider (else provider.yaml platform.provider / $CLOUD_PROVIDER).
#       --cluster <name>         Cluster name (else derived as divyam[-org]-<env>-k8s-cluster).
#       --project <id>           GCP project (else provider.yaml secretsProjectId / `gcloud config`).
#       --region <r> / --zone <z>  GKE location (else $REGION / $ZONE from secrets.env).
#       --resource-group <rg>    AKS resource group (else read from terragrunt output / required for Azure).
#       --login                  Force Azure `az login --service-principal` using ARM_* vars.
#       --no-tf                  Don't query `terragrunt output`; use provider.yaml/secrets.env/convention only.
#   -y, --yes                 Skip confirmations / detail prompts (automation).
#   -n, --dry-run             Print the command(s) that would run; change nothing.
#   -h, --help                Help.
#
# Examples:
#   scripts/k8s.sh config -d k8s/helm-values -e prod   # remember these
#   scripts/k8s.sh kubeconfig                           # auth + fetch kubeconfig (uses secrets.env)
#   scripts/k8s.sh kubeconfig -c azure --resource-group my-rg --cluster my-aks
#   scripts/k8s.sh diff
#   scripts/k8s.sh install -C stable                    # install the latest stable release
#   scripts/k8s.sh install -C stable -a 1.0.0           # install a specific stable version
#   scripts/k8s.sh upgrade -C nightly -a latest         # upgrade to the latest nightly
#   scripts/k8s.sh install -a 26.04.01-rc1              # legacy flat release id (back-compat)
#   scripts/k8s.sh upgrade -l router                    # upgrade one release
#   scripts/k8s.sh status --tui                         # release state in the terminal UI
#   scripts/k8s.sh delete -l clickhouse                 # uninstall one release (type-to-confirm)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="$REPO_ROOT/k8s"
HELMFILE="$K8S_DIR/helmfile.yaml.gotmpl"
CONF="$REPO_ROOT/.k8s.conf"
# shellcheck source=scripts/lib/cli.sh
source "$REPO_ROOT/scripts/lib/cli.sh"

# --- arg parsing (supports -x, --x, and --x=value) -------------------------
SUBCMD=""; RELEASE=""; FILTER=""; ASSUME_YES=0; DRYRUN=0
STATUS_TUI=0; STATUS_DASH=0; PASSTHRU=()
CLI_VDIR=""; CLI_ENV=""; CLI_ARTIFACTS=""; CLI_CHANNEL=""
CLI_CLOUD=""; CLUSTER=""; PROJECT=""; REGION_F=""; ZONE_F=""; RESOURCE_GROUP=""; DO_LOGIN=0; NO_TF=0
usage() { cli::usage "$0"; }
die() { cli::die "$@"; }   # ❌-prefixed to stderr, exit 2 (shared lib; preserves prior exit code)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--release) RELEASE="${2:?--release needs a value}"; shift 2;;
    --release=*)  RELEASE="${1#*=}"; shift;;
    -f|--filter)  FILTER="${2:?--filter needs a value}"; shift 2;;
    --filter=*)   FILTER="${1#*=}"; shift;;
    -e|--env)     CLI_ENV="${2:?--env needs a value}"; shift 2;;
    --env=*)      CLI_ENV="${1#*=}"; shift;;
    -d|--values-dir) CLI_VDIR="${2:?--values-dir needs a value}"; shift 2;;
    --values-dir=*)  CLI_VDIR="${1#*=}"; shift;;
    -a|--artifacts-version) CLI_ARTIFACTS="${2:?--artifacts-version needs a value}"; shift 2;;
    --artifacts-version=*)  CLI_ARTIFACTS="${1#*=}"; shift;;
    -C|--channel) CLI_CHANNEL="${2:?--channel needs a value}"; shift 2;;
    --channel=*)  CLI_CHANNEL="${1#*=}"; shift;;
    --tui)        STATUS_TUI=1; shift;;
    --dashboard)  STATUS_DASH=1; shift;;
    -c|--cloud)   CLI_CLOUD="${2:?--cloud needs a value}"; shift 2;;
    --cloud=*)    CLI_CLOUD="${1#*=}"; shift;;
    --cluster)    CLUSTER="${2:?--cluster needs a value}"; shift 2;;
    --cluster=*)  CLUSTER="${1#*=}"; shift;;
    --project)    PROJECT="${2:?--project needs a value}"; shift 2;;
    --project=*)  PROJECT="${1#*=}"; shift;;
    --region)     REGION_F="${2:?--region needs a value}"; shift 2;;
    --region=*)   REGION_F="${1#*=}"; shift;;
    --zone)       ZONE_F="${2:?--zone needs a value}"; shift 2;;
    --zone=*)     ZONE_F="${1#*=}"; shift;;
    --resource-group) RESOURCE_GROUP="${2:?--resource-group needs a value}"; shift 2;;
    --resource-group=*) RESOURCE_GROUP="${1#*=}"; shift;;
    --login)      DO_LOGIN=1; shift;;
    --no-tf)      NO_TF=1; shift;;
    -y|--yes)     ASSUME_YES=1; shift;;
    -n|--dry-run) DRYRUN=1; shift;;
    -h|--help)    usage; exit 0;;
    --)           shift; PASSTHRU=("$@"); break;;
    -*)           die "unknown option: $1 (try --help)";;
    *)            if [[ -z "$SUBCMD" ]]; then SUBCMD="$1"; else die "unexpected arg: $1"; fi; shift;;
  esac
done
[[ -n "$SUBCMD" ]] || { usage; exit 0; }

# --- config resolution: flag > env var > .k8s.conf > default ---------------
CONF_VDIR=""; CONF_ENV=""; CONF_ARTIFACTS=""; CONF_CHANNEL=""
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
fi
VALUES_DIR="${CLI_VDIR:-${HELMFILE_VALUES_DIR:-${CONF_VDIR:-k8s/helm-values}}}"
ENV_OVERRIDE="${CLI_ENV:-${ENV:-$CONF_ENV}}"
ARTIFACTS_VERSION="${CLI_ARTIFACTS:-${ARTIFACTS_VERSION:-$CONF_ARTIFACTS}}"
ARTIFACTS_CHANNEL="${CLI_CHANNEL:-${ARTIFACTS_CHANNEL:-$CONF_CHANNEL}}"
# Channel/version are passed through `make k8s -- …`; reject `=` (make would eat NAME=VALUE as a var).
case "${ARTIFACTS_CHANNEL}${ARTIFACTS_VERSION}" in *=*) die "channel/version must be plain tokens (no '=')";; esac
# Accept an absolute --values-dir (e.g. an out-of-repo dir like the sandbox's sky_workdir values);
# only prefix the repo root for relative paths. Otherwise $REPO_ROOT/<abs> never exists.
case "$VALUES_DIR" in /*) BASE="$VALUES_DIR";; *) BASE="$REPO_ROOT/$VALUES_DIR";; esac
ENV_NAME=""

have() { command -v "$1" >/dev/null 2>&1; }
require_vdir() {
  [[ -d "$BASE" ]] || die "no such values dir: $VALUES_DIR (set with -d/--values-dir or: k8s.sh config -d <dir>)"
  [[ -f "$HELMFILE" ]] || die "helmfile not found at ${HELMFILE#"$REPO_ROOT"/}"
}
# Resolve the environment for release-name selectors: -e/.k8s.conf/$ENV, else provider.yaml.
resolve_env() {
  if [[ -n "$ENV_OVERRIDE" ]]; then ENV_NAME="$ENV_OVERRIDE"; return; fi
  ENV_NAME=""
  if have yq && [[ -f "$BASE/provider.yaml" ]]; then
    ENV_NAME="$(yq '.environment // ""' "$BASE/provider.yaml" 2>/dev/null || true)"
    [[ "$ENV_NAME" == "null" ]] && ENV_NAME=""
  fi
}

confirm() {  # yes/no, defaults to No
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  local ans; read -r -p "$1 [y/N] " ans; [[ "$ans" =~ ^[Yy]$ ]]
}
confirm_type() {  # type-to-confirm the given word
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  local word="$1" ans; read -r -p "Type '$word' to confirm: " ans
  [[ "$ans" == "$word" ]] || die "aborted (got '$ans')"
}

# Build the helmfile selector array into SEL. Precedence: -f raw > raw label (-l x=y) > -l <chart>.
SEL=()
build_selector() {
  SEL=()
  if [[ -n "$FILTER" ]]; then SEL=(-l "$FILTER"); return; fi
  [[ -n "$RELEASE" ]] || return 0
  if [[ "$RELEASE" == *=* ]]; then SEL=(-l "$RELEASE"); return; fi
  [[ -n "$ENV_NAME" ]] || die "cannot build name=$RELEASE-<env>: env unknown — pass -e <env> or install yq to read provider.yaml"
  SEL=(-l "name=$RELEASE-$ENV_NAME")
}

# Run a helmfile verb from inside the values dir with the selector + artifacts context.
hf() {  # <diff|sync|apply|destroy|template> [extra args...]
  local verb="$1"; shift || true
  require_vdir; resolve_env; build_selector
  local -a cmd=(helmfile -f "$HELMFILE" "${SEL[@]}" "$verb" "$@" "${PASSTHRU[@]}")
  local ctx="env=${ENV_NAME:-<auto>}"; [[ -n "$ARTIFACTS_VERSION" ]] && ctx+=" ARTIFACTS_VERSION=$ARTIFACTS_VERSION"
  [[ -n "$ARTIFACTS_CHANNEL" ]] && ctx+=" ARTIFACTS_CHANNEL=$ARTIFACTS_CHANNEL"
  echo "+ (cd $VALUES_DIR && ${cmd[*]})   [$ctx]"
  [[ "$DRYRUN" -eq 1 ]] && { echo "  (dry-run: not executed)"; return 0; }
  # Export the ABSOLUTE values dir: helmfile resolves `readFile` in helmfile.yaml.gotmpl relative to
  # the helmfile's own directory (k8s/), not this CWD — so a relative "." can't find provider.yaml
  # when the values dir lives elsewhere. An absolute path resolves correctly regardless of CWD.
  ( cd "$BASE" && export HELMFILE_VALUES_DIR="$BASE"; \
    [[ -n "$ARTIFACTS_VERSION" ]] && export ARTIFACTS_VERSION; \
    [[ -n "$ARTIFACTS_CHANNEL" ]] && export ARTIFACTS_CHANNEL; \
    "${cmd[@]}" )
}

# --- commands ---------------------------------------------------------------
cmd_config() {
  local d="${CLI_VDIR:-$CONF_VDIR}" e="${CLI_ENV:-$CONF_ENV}" a="${CLI_ARTIFACTS:-$CONF_ARTIFACTS}" c="${CLI_CHANNEL:-$CONF_CHANNEL}"
  if [[ -n "$CLI_VDIR" || -n "$CLI_ENV" || -n "$CLI_ARTIFACTS" || -n "$CLI_CHANNEL" ]]; then
    { echo "# k8s.sh remembered config (gitignored). Set via: k8s.sh config -d <dir> -e <env> -a <ver> -C <channel>"
      echo "CONF_VDIR=$d"; echo "CONF_ENV=$e"; echo "CONF_ARTIFACTS=$a"; echo "CONF_CHANNEL=$c"; } > "$CONF"
    chmod 600 "$CONF"
    echo "saved $CONF"
  fi
  echo "values-dir        = ${d:-k8s/helm-values (default)}"
  echo "env               = ${e:-<auto from provider.yaml>}"
  echo "artifacts-channel = ${c:-<none: local artifacts.yaml / stable latest>}"
  echo "artifacts-version = ${a:-<latest in channel / helmfile default>}"
  [[ -f "$CONF" ]] || echo "(nothing persisted yet — run: k8s.sh config -d k8s/helm-values -e prod)"
}

cmd_change() {  # <sync|apply> with auto-diff + confirm
  local verb="$1" label="$2"
  if [[ "$ASSUME_YES" -ne 1 && "$DRYRUN" -ne 1 ]]; then
    echo "-- diff preview before $label --"
    set +e; hf diff; set -e
    confirm "Proceed with $label?" || die "aborted"
  fi
  hf "$verb"
}

cmd_delete() {
  require_vdir; resolve_env
  local what="${RELEASE:-the whole stack}"
  echo "== DELETE $what (env=${ENV_NAME:-<auto>}, values-dir=$VALUES_DIR) =="
  confirm_type "${RELEASE:-all}"
  hf destroy
}

launch_tui() {
  if ! { have helm && helm plugin list 2>/dev/null | grep -qi '^tui'; }; then
    die "helm-tui not installed — run: make prereqs (installs pidanou/helm-tui)"
  fi
  echo "+ (helm tui)"
  [[ "$DRYRUN" -eq 1 ]] && { echo "  (dry-run: not executed)"; return 0; }
  helm tui
}
launch_dash() {
  if ! { have helm && helm plugin list 2>/dev/null | grep -qi '^dashboard'; }; then
    die "helm dashboard not installed — run: make prereqs (installs Komodor helm-dashboard)"
  fi
  # Bind-all + no browser: this usually runs on a headless bastion/VM — the human reaches it from
  # their machine (sandbox: route the subnet with `make sshuttle`, then open the URL below).
  local port="${HELM_DASHBOARD_PORT:-8080}" ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  echo "+ (helm dashboard --bind=0.0.0.0 --port=${port} --no-browser)"
  echo "  open: http://${ip:-<this-host>}:${port}  (from a laptop: route the VM subnet first, e.g. make sshuttle)"
  [[ "$DRYRUN" -eq 1 ]] && { echo "  (dry-run: not executed)"; return 0; }
  helm dashboard --bind=0.0.0.0 --port="$port" --no-browser
}

cmd_status() {
  echo "+ (helm ls -A)"
  if [[ "$DRYRUN" -ne 1 ]]; then helm ls -A; fi
  # Explicit view flags win.
  if [[ "$STATUS_TUI" -eq 1 ]]; then launch_tui; return; fi
  if [[ "$STATUS_DASH" -eq 1 ]]; then launch_dash; return; fi
  # Non-interactive (or dry-run): just the list.
  [[ "$ASSUME_YES" -eq 1 || "$DRYRUN" -eq 1 ]] && return 0
  local ans; read -r -p "Open more detail? [t]ui / [d]ashboard / [N]one " ans
  case "$ans" in t|T) launch_tui;; d|D) launch_dash;; *) : ;; esac
}

# Read a scalar from provider.yaml via yq (empty if yq/file/key absent).
provider_yaml_get() {  # <yq-path>
  local pv="$BASE/provider.yaml" out=""
  if have yq && [[ -f "$pv" ]]; then out="$(yq "$1 // \"\"" "$pv" 2>/dev/null || true)"; fi
  [[ "$out" == "null" ]] && out=""
  printf '%s' "$out"
}

# Read an output from the created 1-platform/1-k8s/<cloud> unit via `terragrunt output`
# (the actual provisioned values; survives bring-your-own naming). Empty on any failure.
tf_out() {  # <cloud> <output-name> [-raw|-json]
  local cl="$1" name="$2" fmt="${3:--raw}"
  local dir="$REPO_ROOT/iac/1-platform/1-k8s/$cl"
  [[ -d "$dir" ]] || return 0
  ( cd "$dir" && CLOUD_PROVIDER="$cl" terragrunt output "$fmt" "$name" 2>/dev/null ) || true
}

# Authenticate to the cloud and (re)fetch the cluster kubeconfig.
# Resolves identifiers from flags first, then iac/values/secrets.env + provider.yaml.
cmd_kubeconfig() {
  local SF="$REPO_ROOT/iac/values/secrets.env"
  if [[ -f "$SF" ]]; then set -a; # shellcheck disable=SC1090
    source "$SF"; set +a; echo "k8s.sh: loaded ${SF#"$REPO_ROOT"/}" >&2; fi

  local cloud="${CLI_CLOUD:-}"
  [[ -z "$cloud" ]] && cloud="$(provider_yaml_get '.platform.provider' | tr 'A-Z' 'a-z')"
  [[ -z "$cloud" ]] && cloud="${CLOUD_PROVIDER:-}"
  case "$cloud" in gcp|azure) ;; *) die "cloud unknown — pass -c gcp|azure (got '${cloud:-}')";; esac

  # Cluster name (+ Azure RG): prefer the ACTUAL created resources via `terragrunt output`, then
  # fall back to the deployment-prefix convention. Flags always win; --no-tf skips terragrunt.
  local cluster="${CLUSTER:-}" rg="${RESOURCE_GROUP:-}" src=""
  if [[ "$NO_TF" -ne 1 ]] && have terragrunt && { [[ -z "$cluster" ]] || { [[ "$cloud" == azure ]] && [[ -z "$rg" ]]; }; }; then
    if [[ "$cloud" == azure ]]; then
      [[ -z "$cluster" ]] && cluster="$(tf_out azure aks_cluster_name)"
      if [[ -z "$rg" ]]; then
        local cid; cid="$(tf_out azure aks_cluster_id)"
        rg="$(printf '%s' "$cid" | sed -nE 's#.*/[rR]esource[gG]roups/([^/]+)/.*#\1#p')"
      fi
    else
      local eps; eps="$(tf_out gcp cluster_endpoints -json)"
      if [[ -n "$eps" ]] && have jq; then
        local c; c="$(printf '%s' "$eps" | jq -r 'keys[0] // empty' 2>/dev/null || true)"
        [[ -n "$c" ]] && cluster="$c"
      fi
    fi
    [[ -n "$cluster" ]] && src="terragrunt output"
  fi
  # Fallback: deployment-prefix convention from the resolved env (-e flag > $ENV > .k8s.conf) + ORG_NAME.
  if [[ -z "$cluster" ]]; then
    local org="${ORG_NAME:-}" env="${ENV_OVERRIDE:-}"
    if [[ -n "$env" ]]; then
      [[ -n "$org" ]] && cluster="divyam-$org-$env-k8s-cluster" || cluster="divyam-$env-k8s-cluster"
      src="convention"
    fi
  fi
  [[ -n "$cluster" ]] || die "cluster name unknown — apply 1-k8s first, or pass --cluster"
  [[ -n "$src" ]] && echo "k8s.sh: cluster '$cluster'${rg:+ (resource-group $rg)} via $src" >&2

  if [[ "$cloud" == gcp ]]; then
    local project="${PROJECT:-}"
    [[ -z "$project" ]] && project="$(provider_yaml_get '.platform.gcp.secretsProjectId')"
    if [[ -z "$project" ]] && have gcloud; then project="$(gcloud config get-value project 2>/dev/null || true)"; fi
    [[ "$project" == "(unset)" ]] && project=""
    [[ -n "$project" ]] || die "GCP project unknown — pass --project"
    local loc_flag="" loc_val=""
    if   [[ -n "$ZONE_F"        ]]; then loc_flag="--zone";   loc_val="$ZONE_F"
    elif [[ -n "$REGION_F"      ]]; then loc_flag="--region"; loc_val="$REGION_F"
    elif [[ -n "${REGION:-}"    ]]; then loc_flag="--region"; loc_val="$REGION"
    elif [[ -n "${ZONE:-}"      ]]; then loc_flag="--zone";   loc_val="$ZONE"
    else die "GKE location unknown — pass --region or --zone"; fi
    if [[ "$DRYRUN" -ne 1 ]]; then CLOUD_PROVIDER=gcp "$REPO_ROOT/scripts/check_cloud_credentials.sh" || die "GCP credentials check failed"; fi
    local -a cmd=(gcloud container clusters get-credentials "$cluster" "$loc_flag" "$loc_val" --project "$project")
    echo "+ ${cmd[*]}"
    [[ "$DRYRUN" -eq 1 ]] && { echo "  (dry-run: not executed)"; return 0; }
    "${cmd[@]}"
  else
    if [[ -z "$rg" ]]; then
      # Dry-run is a preview — don't fail on unresolved identifiers, show a placeholder instead.
      [[ "$DRYRUN" -eq 1 ]] && rg="<resource-group>" \
        || die "Azure resource group unknown — apply 1-k8s first, or pass --resource-group (= resource_scope.name)"
    fi
    # Auth: SP login when forced, or when no active az session and ARM_* are available.
    if [[ "$DO_LOGIN" -eq 1 ]] || { [[ "$DRYRUN" -ne 1 ]] && ! az account show >/dev/null 2>&1; }; then
      [[ -n "${ARM_CLIENT_ID:-}" && -n "${ARM_CLIENT_SECRET:-}" && -n "${ARM_TENANT_ID:-}" ]] \
        || die "Azure login needed but ARM_CLIENT_ID/SECRET/TENANT not set (fill iac/values/secrets.env, or run: az login)"
      echo "+ az login --service-principal -u <ARM_CLIENT_ID> -p <hidden> --tenant <ARM_TENANT_ID>"
      if [[ "$DRYRUN" -ne 1 ]]; then
        az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" >/dev/null
        [[ -n "${ARM_SUBSCRIPTION_ID:-}" ]] && az account set --subscription "$ARM_SUBSCRIPTION_ID"
      fi
    fi
    local -a cmd=(az aks get-credentials --resource-group "$rg" --name "$cluster" --overwrite-existing)
    echo "+ ${cmd[*]}"
    [[ "$DRYRUN" -eq 1 ]] && { echo "  (dry-run: not executed)"; return 0; }
    "${cmd[@]}"
  fi
  echo "kubeconfig updated for '$cluster'. Verify with: kubectl get ns"
}

# Keep the bringup status ledger live (see `make status` / bringup.sh status) when this command IS
# a bringup step: `kubeconfig` and `install` (the full-stack sync). upgrade/diff/etc. don't map to
# a bringup step and are not stamped. Best-effort: skipped when cloud/env can't be resolved.
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/status-ledger.sh"
ledger_cloud() {
  local c="${CLI_CLOUD:-}"
  [[ -z "$c" ]] && c="$(provider_yaml_get '.platform.provider' 2>/dev/null | tr 'A-Z' 'a-z' || true)"
  [[ -z "$c" ]] && c="${CLOUD_PROVIDER:-}"
  echo "$c"
}
k8s_stamped() {  # <step> <cmd...> — subshell so an inner `die`/exit still lands a failed stamp
  local step="$1"; shift
  local c e; c="$(ledger_cloud)"; e="${ENV_OVERRIDE:-}"
  if [[ "$DRYRUN" -eq 1 || -z "$c" || -z "$e" ]]; then "$@"; return "$?"; fi
  ledger_stamp "$REPO_ROOT" "$c" "$e" "$step" running
  local rc=0; ( "$@" ) || rc=$?
  if [[ "$rc" -eq 0 ]]; then ledger_stamp "$REPO_ROOT" "$c" "$e" "$step" applied
  else ledger_stamp "$REPO_ROOT" "$c" "$e" "$step" failed; fi
  return "$rc"
}

case "$SUBCMD" in
  config)            cmd_config;;
  diff)              hf diff;;
  install)           k8s_stamped k8s-install cmd_change sync "install (helmfile sync)";;
  upgrade)           cmd_change apply "upgrade (helmfile apply)";;
  delete|destroy)    cmd_delete;;
  template)          hf template;;
  status|ls)         cmd_status;;
  kubeconfig|auth)   k8s_stamped kubeconfig cmd_kubeconfig;;
  help)              usage;;
  *)                 die "unknown command: $SUBCMD (try --help)";;
esac
