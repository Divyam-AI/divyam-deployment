#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# set-prevent-destroy.sh — flip Terraform `lifecycle { prevent_destroy = ... }` across a
# target module (one iac/ layer, scoped by sub-unit + cloud), with per-file backups.
#
# Why: critical resources (resource groups, VNets, the TF state bucket, secret vaults)
# ship with prevent_destroy=true, which blocks `terragrunt destroy`. Flip to false to tear
# an env down; flip to true to (re)harden. Backups (*.pdbak) let you restore the originals.
#
# Usage:
#   scripts/set-prevent-destroy.sh -l <layer1[.layer2]> -c <gcp|azure> --set <true|false> [--run <verb>] [-y]
#   scripts/set-prevent-destroy.sh -l <layer1[.layer2]> -c <gcp|azure> --restore
#
# Options:
#   -l, --layer  <layer1[.layer2]>  Target layer (layer2 omitted -> all sub-units).
#   -c, --cloud  <gcp|azure>        Restrict edits to the cloud's units.
#       --set    <true|false>       Value to write into every prevent_destroy.
#       --run    <plan|apply|destroy>  After editing, fire `terragrunt run <verb>` for the same scope.
#       --restore                   Restore originals from *.pdbak backups (and remove the backups).
#   -y, --yes                       Skip the confirmation prompt.
#   -h, --help                      Help.
#
# Notes:
#   * Edits the SOURCE .tf files in iac/ (terragrunt re-copies them to .terragrunt-cache on next run).
#     These are tracked files — restore with --restore, or `git checkout -- <files>`.
#   * .terragrunt-cache copies are never touched.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IAC_DIR="$REPO_ROOT/iac"
# shellcheck source=scripts/lib/cli.sh
source "$REPO_ROOT/scripts/lib/cli.sh"

LAYER=""; CLOUD=""; SET_VAL=""; RUN=""; YES=0; RESTORE=0
usage() { cli::usage "$0"; }
die() { cli::die "$@"; }   # ❌-prefixed to stderr, exit 2 (shared lib; preserves prior exit code)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--layer) LAYER="${2:?}"; shift 2;;
    --layer=*)  LAYER="${1#*=}"; shift;;
    -c|--cloud) CLOUD="${2:?}"; shift 2;;
    --cloud=*)  CLOUD="${1#*=}"; shift;;
    --set)      SET_VAL="${2:?}"; shift 2;;
    --set=*)    SET_VAL="${1#*=}"; shift;;
    --run)      RUN="${2:?}"; shift 2;;
    --run=*)    RUN="${1#*=}"; shift;;
    --restore)  RESTORE=1; shift;;
    -y|--yes)   YES=1; shift;;
    -h|--help)  usage; exit 0;;
    *)          die "unknown arg: $1 (try --help)";;
  esac
done

[[ -n "$LAYER" ]] || die "missing -l/--layer"
LAYER1="${LAYER%%.*}"
if [[ "$LAYER" == *.* ]]; then LAYER2="${LAYER#*.}"; else LAYER2="**"; fi
BASE="$IAC_DIR/$LAYER1"
[[ -d "$BASE" ]] || die "no such layer dir: iac/$LAYER1"

# --- restore mode ----------------------------------------------------------
if [[ "$RESTORE" -eq 1 ]]; then
  n=0
  while IFS= read -r b; do
    mv -f "$b" "${b%.pdbak}"; echo "restored ${b%.pdbak}"; n=$((n+1))
  done < <(find "$BASE" -type f -name '*.pdbak' -not -path '*/.terragrunt-cache/*')
  echo "restored $n file(s)."; exit 0
fi

# --- edit mode -------------------------------------------------------------
case "$SET_VAL" in true|false) ;; *) die "--set must be true|false (got '${SET_VAL:-}')";; esac

# Collect target .tf files: under the layer, matching sub-unit + cloud, containing prevent_destroy.
targets=()
while IFS= read -r f; do
  grep -Eq 'prevent_destroy[[:space:]]*=' "$f" || continue
  [[ "$LAYER2" != "**" && "$f" != *"/$LAYER2/"* ]] && continue
  [[ -n "$CLOUD" && "$f" != *"/$CLOUD/"* ]] && continue
  targets+=("$f")
done < <(find "$BASE" -type f -name '*.tf' -not -path '*/.terragrunt-cache/*' | sort)

if [[ "${#targets[@]}" -eq 0 ]]; then
  echo "no prevent_destroy declarations found under iac/$LAYER1 (layer2=$LAYER2, cloud=${CLOUD:-any}). Nothing to do."
  exit 0
fi

echo "Will set prevent_destroy=$SET_VAL in ${#targets[@]} file(s) (cloud=${CLOUD:-any}, layer2=$LAYER2):"
for f in "${targets[@]}"; do
  echo "  ${f#"$REPO_ROOT"/}  ($(grep -cE 'prevent_destroy[[:space:]]*=' "$f") occurrence(s))"
done
if [[ "$YES" -ne 1 ]]; then
  read -r -p "Proceed? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] || die "aborted"
fi

for f in "${targets[@]}"; do
  [[ -f "$f.pdbak" ]] || cp -p "$f" "$f.pdbak"          # back up original once
  tmp="$(mktemp)"
  sed -E "s/(prevent_destroy[[:space:]]*=[[:space:]]*)(true|false)/\1$SET_VAL/g" "$f" > "$tmp"
  mv "$tmp" "$f"
  echo "set $SET_VAL: ${f#"$REPO_ROOT"/}"
done
echo "Backups written as *.pdbak. Restore with: $0 -l $LAYER ${CLOUD:+-c $CLOUD }--restore"

# --- optional follow-up terragrunt run -------------------------------------
if [[ -n "$RUN" ]]; then
  [[ -n "$CLOUD" ]] || die "--run needs -c/--cloud to build the filter"
  # cd into the target dir, then select the cloud's units with the verified union of
  # four anchored filters (cloud sits at varying depth; terragrunt's ** never matches zero).
  runbase="$BASE"; [[ "$LAYER2" != "**" ]] && runbase="$BASE/$LAYER2"
  [[ -d "$runbase" ]] || die "no such path: ${runbase#"$REPO_ROOT"/}"
  flt=(--filter "./$CLOUD" --filter "./$CLOUD/**" --filter "./**/$CLOUD" --filter "./**/$CLOUD/**")
  echo "+ (cd ${runbase#"$REPO_ROOT"/} && terragrunt run $RUN --all ${flt[*]})   [CLOUD_PROVIDER=$CLOUD]"
  ( cd "$runbase" && CLOUD_PROVIDER="$CLOUD" terragrunt run "$RUN" --all "${flt[@]}" )
fi
