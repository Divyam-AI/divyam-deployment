#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# iac.sh — Phase-1 Terragrunt workflow CLI for this repo.
#
# A single entrypoint over the documented Terragrunt flow, with standard CLI args
# (short -x and long --xxx), dotted layer addressing, and a remembered cloud/env so
# you don't repeat yourself. Nothing here hides logic — every run prints the exact
# `terragrunt` command it executes (see CLAUDE.md "Phase 1" and the terragrunt-ops skill).
#
# Usage:
#   scripts/iac.sh <command> [options]
#
# Commands:
#   config            Show or set the remembered cloud/env (persisted to .iac.conf)
#   secrets           Generate the TF_VAR_* secrets env file (wraps gen-tf-env.sh)
#   creds             Validate cloud credentials (wraps check_cloud_credentials.sh)
#   init              terragrunt init -reconfigure for a layer
#   plan              terragrunt run plan for a layer (review before apply)
#   apply             terragrunt run apply for a layer
#   show              terragrunt show for a layer
#   destroy           Plan-preview + type-to-confirm, then terragrunt run destroy
#                       (first flips prevent_destroy -> false on the target module)
#   protect           Set prevent_destroy -> true on the target module, then apply
#   help              This help
#
# Options:
#   -l, --layer  <layer1[.layer2]>  Target layer. layer1 is a dir under iac/ (e.g. 1-platform).
#                                   layer2 is the sub-unit (e.g. 1-k8s, 2-monitoring); omit -> ** (all).
#   -c, --cloud  <gcp|azure>        Cloud provider. Falls back to $CLOUD_PROVIDER, then .iac.conf.
#   -e, --env    <name>             Environment name. Falls back to $ENV, then .iac.conf.
#   -f, --filter <glob>             Override the computed terragrunt --filter (for irregular units).
#   -y, --yes                       Skip confirmation prompts (automation).
#   -n, --dry-run                   Print the terragrunt command(s) that would run; change nothing.
#   -h, --help                      Help.
#
# Examples:
#   scripts/iac.sh config -c gcp -e dev            # remember these; later commands need no -c/-e
#   scripts/iac.sh secrets                          # uses remembered cloud/env
#   scripts/iac.sh creds
#   scripts/iac.sh plan    -l 1-platform.1-k8s
#   scripts/iac.sh apply   --layer 1-platform.2-monitoring
#   scripts/iac.sh destroy -l 0-foundation          # type-to-confirm
#   scripts/iac.sh protect -l 2-app.0-divyam_secrets
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IAC_DIR="$REPO_ROOT/iac"
SCRIPTS="$REPO_ROOT/scripts"
CONF="$REPO_ROOT/.iac.conf"

# --- arg parsing (supports -x, --x, and --x=value) -------------------------
SUBCMD=""; LAYER=""; FILTER=""; ASSUME_YES=0; DRYRUN=0
CLI_CLOUD=""; CLI_ENV=""
usage() { grep '^#' "$0" | grep -vE '^#(!|[[:space:]]*SPDX-)' | sed 's/^# \{0,1\}//'; }
die() { echo "iac.sh: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--layer)  LAYER="${2:?--layer needs a value}"; shift 2;;
    --layer=*)   LAYER="${1#*=}"; shift;;
    -c|--cloud)  CLI_CLOUD="${2:?--cloud needs a value}"; shift 2;;
    --cloud=*)   CLI_CLOUD="${1#*=}"; shift;;
    -e|--env)    CLI_ENV="${2:?--env needs a value}"; shift 2;;
    --env=*)     CLI_ENV="${1#*=}"; shift;;
    -f|--filter) FILTER="${2:?--filter needs a value}"; shift 2;;
    --filter=*)  FILTER="${1#*=}"; shift;;
    -y|--yes)    ASSUME_YES=1; shift;;
    -n|--dry-run) DRYRUN=1; shift;;
    -h|--help)   usage; exit 0;;
    --)          shift; break;;
    -*)          die "unknown option: $1 (try --help)";;
    *)           if [[ -z "$SUBCMD" ]]; then SUBCMD="$1"; else die "unexpected arg: $1"; fi; shift;;
  esac
done
[[ -n "$SUBCMD" ]] || { usage; exit 0; }

# --- load config + secrets -------------------------------------------------
# Capture the pre-existing shell env (it outranks the file) before sourcing anything.
ENV_CLOUD="${CLOUD_PROVIDER:-}"; ENV_ENV="${ENV:-}"
# The IaC reads config via terragrunt get_env(); auto-source iac/values/secrets.env so the
# TF_VAR_* secrets and config vars (REGION/ZONE/ORG_NAME/NOTIFICATION_*/...) are present.
# Generate it with scripts/gen-tf-env.sh. Lowest precedence for cloud/env.
SECRETS_FILE="$IAC_DIR/values/secrets.env"; LOADED_SECRETS=0
if [[ -f "$SECRETS_FILE" ]]; then
  set -a; # shellcheck disable=SC1090
  source "$SECRETS_FILE"; set +a; LOADED_SECRETS=1
fi
# Persisted cloud/env selection from `iac.sh config`.
CONF_CLOUD=""; CONF_ENV=""
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
fi
# resolve: CLI flag > pre-existing env > .iac.conf > secrets.env value
CLOUD="${CLI_CLOUD:-${ENV_CLOUD:-${CONF_CLOUD:-${CLOUD_PROVIDER:-}}}}"
ENV_NAME="${CLI_ENV:-${ENV_ENV:-${CONF_ENV:-${ENV:-}}}}"
[[ "$LOADED_SECRETS" -eq 1 && "$SUBCMD" != "help" ]] && echo "iac.sh: loaded ${SECRETS_FILE#"$REPO_ROOT"/}" >&2

# Guard the silent state-key fork. The remote-state key embeds the VALUES_FILE basename, so a
# VALUES_FILE pointing at a missing file (classically a stale value baked into secrets.env) resolves
# to a DIFFERENT, empty state while the resources already exist in the cloud → cascading
# "already exists". Fail loudly here instead. (CLOUD_PROVIDER/ENV/VALUES_FILE are config and belong in
# .iac.conf / flags / iac.env — not in the secrets file.)
case "$SUBCMD" in help|config|secrets|creds) ;; *)
  if [[ -n "${VALUES_FILE:-}" && ! -f "$IAC_DIR/$VALUES_FILE" ]]; then
    die "VALUES_FILE='$VALUES_FILE' but iac/$VALUES_FILE does not exist. The Terraform state key embeds
   this filename, so a wrong/stale VALUES_FILE silently forks state (empty state vs already-created
   resources). Point VALUES_FILE at an existing values file, or unset it in iac/values/secrets.env
   (config belongs in .iac.conf / -e / iac.env). If resources already exist, adopt them — see the
   /import-existing recovery flow."
  fi
;;
esac

# Naming validation. The env must be one of a small allowlist (both clouds — for consistent, bounded
# state keys), and on Azure the derived names must fit the 24-char Storage Account / Key Vault limit.
# deployment_prefix = "divyam-[<org>-]<env>"; the tightest derived name is the Key Vault
# "divyam-<org>-<env>-vault" (24 chars) → len(org)+len(env) <= 10 (storage, dashes stripped, allows
# <= 11). No guard existed before, so a long env/org failed mid-apply (e.g. an invalid 27-char
# storage account). Fail fast here. Widen ALLOWED_ENVS below to permit more envs.
ALLOWED_ENVS="dev prod preprod stage sandbox"
validate_naming() {
  [[ -z "$ENV_NAME" ]] && return 0   # no env chosen yet (e.g. creds/secrets) — nothing to validate
  case " $ALLOWED_ENVS " in
    *" $ENV_NAME "*) ;;
    *) die "ENV '$ENV_NAME' is not allowed — use one of: $ALLOWED_ENVS (keeps Azure storage/Key Vault names <= 24 chars; widen ALLOWED_ENVS in scripts/iac.sh to change)";;
  esac
  local org="${ORG_NAME:-}"
  if [[ -n "$org" && ! "$org" =~ ^[a-z0-9]+$ ]]; then
    die "ORG_NAME '$org' must be lowercase letters/digits only (it forms Azure storage-account names, which forbid dashes/uppercase)"
  fi
  if [[ "$CLOUD" == "azure" && $(( ${#org} + ${#ENV_NAME} )) -gt 10 ]]; then
    die "ORG_NAME+ENV too long for Azure: Key Vault 'divyam-${org:+$org-}${ENV_NAME}-vault' exceeds the 24-char limit (len(org)+len(env) must be <= 10; got $(( ${#org} + ${#ENV_NAME} ))). Shorten ORG_NAME or use a shorter env."
  fi
}
if [[ "$SUBCMD" != "help" ]]; then validate_naming; fi

require_cloud() { [[ -n "$CLOUD" ]] || die "no cloud set — pass -c gcp|azure or run: iac.sh config -c <cloud>"; \
  case "$CLOUD" in gcp|azure) ;; *) die "cloud must be gcp|azure (got '$CLOUD')";; esac; }
require_env()   { [[ -n "$ENV_NAME" ]] || die "no env set — pass -e <name> or run: iac.sh config -e <env>"; }
require_layer() { [[ -n "$LAYER" ]] || die "no layer set — pass -l <layer1[.layer2]>"; }

# --- layer resolution ------------------------------------------------------
# A target is a directory we cd into, then run `terragrunt run --all` over. layer1 is
# a dir under iac/; the optional .layer2 is a sub-unit dir (e.g. 1-k8s, 2-monitoring,
# 2-alerts). Within a target, ordering (e.g. 1-k8s before 2-monitoring) is enforced by
# the terragrunt dependency DAG — no manual sequencing needed.
LAYER1=""; LAYER2=""; BASE=""
parse_layer() {
  LAYER1="${LAYER%%.*}"
  if [[ "$LAYER" == *.* ]]; then LAYER2="${LAYER#*.}"; else LAYER2=""; fi
  BASE="$IAC_DIR/$LAYER1"; [[ -n "$LAYER2" ]] && BASE="$BASE/$LAYER2"
  [[ -d "$BASE" ]] || die "no such path: iac/$LAYER1${LAYER2:+/$LAYER2} (check layer1[.layer2])"
}
# Cloud selection: the cloud token sits at an inconsistent depth across the tree
# (leaf in 0-foundation/1-platform, an ANCESTOR in 2-app/2-alerts) and terragrunt's
# `**` matches one-or-more segments (never zero). A single glob therefore can't select
# all of a cloud's units without silently dropping some. The verified-complete set is
# the UNION of four anchored forms (terragrunt ORs multiple --filter); -f/--filter overrides.
filter_args() {
  if [[ -n "$FILTER" ]]; then printf '%s\n' --filter "$FILTER"; return; fi
  printf '%s\n' --filter "./$CLOUD" --filter "./$CLOUD/**" --filter "./**/$CLOUD" --filter "./**/$CLOUD/**"
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

# Run a terragrunt verb over the target dir with the cloud-union filter + exported context.
tg() {  # <init|plan|apply|show|destroy> [extra tofu args...]
  local verb="$1"; shift || true
  require_cloud; require_layer; parse_layer
  export CLOUD_PROVIDER="$CLOUD" ENV="$ENV_NAME"
  local -a flt; mapfile -t flt < <(filter_args)
  local -a cmd
  case "$verb" in
    init) cmd=(terragrunt init -reconfigure --all "${flt[@]}");;
    show) cmd=(terragrunt show --all "${flt[@]}");;
    *)    cmd=(terragrunt run "$verb" --all "${flt[@]}" "$@");;
  esac
  echo "+ (cd ${BASE#"$REPO_ROOT"/} && ${cmd[*]})   [CLOUD_PROVIDER=$CLOUD ENV=$ENV_NAME]"
  [[ "$DRYRUN" -eq 1 ]] && { echo "  (dry-run: not executed)"; return 0; }
  ( cd "$BASE" && "${cmd[@]}" )
}

# --- commands ---------------------------------------------------------------
cmd_config() {
  local c="${CLI_CLOUD:-$CONF_CLOUD}" e="${CLI_ENV:-$CONF_ENV}"
  if [[ -n "$CLI_CLOUD" || -n "$CLI_ENV" ]]; then
    { echo "# iac.sh remembered config (gitignored). Set via: iac.sh config -c <cloud> -e <env>"
      echo "CONF_CLOUD=$c"; echo "CONF_ENV=$e"; } > "$CONF"
    chmod 600 "$CONF"
    echo "saved $CONF"
  fi
  echo "cloud = ${c:-<unset>}"
  echo "env   = ${e:-<unset>}"
  [[ -f "$CONF" ]] || echo "(nothing persisted yet — run: iac.sh config -c gcp -e dev)"
}

cmd_secrets() {
  require_cloud; require_env
  "$SCRIPTS/gen-tf-env.sh" --cloud "$CLOUD" --env "$ENV_NAME"
}

cmd_creds() {
  require_cloud
  CLOUD_PROVIDER="$CLOUD" "$SCRIPTS/check_cloud_credentials.sh"
}

cmd_destroy() {
  require_cloud; require_layer; parse_layer
  echo "== DESTROY iac/$LAYER1${LAYER2:+/$LAYER2} (cloud=$CLOUD, env=$ENV_NAME) =="
  # 1. unblock: flip prevent_destroy -> false on the target module (with backups)
  local yflag=(); [[ "$ASSUME_YES" -eq 1 ]] && yflag=(--yes)
  if [[ "$DRYRUN" -eq 1 ]]; then
    echo "+ scripts/set-prevent-destroy.sh -l $LAYER -c $CLOUD --set false   (dry-run: not executed)"
  else
    "$SCRIPTS/set-prevent-destroy.sh" -l "$LAYER" -c "$CLOUD" --set false "${yflag[@]}"
  fi
  # 2. plan-preview the destroy
  echo "-- destroy plan preview --"
  set +e; tg plan -destroy; local rc=$?; set -e
  [[ $rc -eq 0 ]] || echo "(destroy-plan preview returned $rc — review above before confirming)"
  # 3. type-to-confirm, then destroy
  confirm_type "$LAYER"
  tg destroy
  echo
  echo "Done. prevent_destroy was flipped to false in source files; restore it with:"
  echo "  scripts/set-prevent-destroy.sh -l $LAYER -c $CLOUD --restore"
}

cmd_protect() {
  require_cloud; require_layer; parse_layer
  local yflag=(); [[ "$ASSUME_YES" -eq 1 ]] && yflag=(--yes)
  if [[ "$DRYRUN" -eq 1 ]]; then
    echo "+ scripts/set-prevent-destroy.sh -l $LAYER -c $CLOUD --set true   (dry-run: not executed)"
  else
    "$SCRIPTS/set-prevent-destroy.sh" -l "$LAYER" -c "$CLOUD" --set true "${yflag[@]}"
  fi
  tg apply
}

case "$SUBCMD" in
  config)  cmd_config;;
  secrets) cmd_secrets;;
  creds|creds-check) cmd_creds;;
  init)    tg init;;
  plan)    tg plan;;
  apply)   tg apply;;
  show)    tg show;;
  destroy) cmd_destroy;;
  protect) cmd_protect;;
  help)    usage;;
  *)       die "unknown command: $SUBCMD (try --help)";;
esac
