#!/usr/bin/env bash
# Collect Terragrunt/Terraform outputs from all modules in a layer (for a cloud) and write
# a single outputs.yaml (and optionally outputs.json) for Helm or other consumers.
# Include/exclude config is read from root.hcl (locals.outputs_for_helm). Sensitive outputs are excluded by default.
#
# Usage:
#   ./scripts/write-outputs-yaml.sh [LAYER] [CLOUD_PROVIDER] [REPO_ROOT] [VALUES_FILE]
#   Or set env: LAYER, CLOUD_PROVIDER, REPO_ROOT, VALUES_FILE
#
# Output path and format from values file (locals.outputs_file_path): extension .yaml/.yml = YAML, .json = JSON.

set -euo pipefail

REPO_ROOT="${3:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LAYER="${1:-${LAYER:-0}}"
CLOUD_PROVIDER="${2:-${CLOUD_PROVIDER:-azure}}"
VALUES_FILE="${4:-${VALUES_FILE:-values/defaults.hcl}}"

case "${LAYER}" in
  0) TG_DIR="0-foundation" ;;
  1) TG_DIR="1-platform" ;;
  2) TG_DIR="2-app" ;;
  *) echo "Error: LAYER must be 0, 1, or 2 (got: ${LAYER})"; exit 1 ;;
esac
if [[ "${CLOUD_PROVIDER}" != "azure" && "${CLOUD_PROVIDER}" != "gcp" ]]; then
  echo "Error: CLOUD_PROVIDER must be azure or gcp (got: ${CLOUD_PROVIDER})"
  exit 1
fi

# Config is read from root.hcl (locals.outputs_for_helm)
HCL_CONFIG_FILE="${REPO_ROOT}/root.hcl"
# Output file path: from values file (locals.outputs_file_path). May contain ${local.deployment_prefix}, ${local.env_name}, ${local.org_name} — resolved using ENV and ORG_NAME.
read_outputs_file_path() {
  local vfile="$1"
  python3 - "$vfile" << 'PY'
import re, sys
path = sys.argv[1]
try:
    with open(path) as f:
        content = f.read()
except Exception:
    print("")
    sys.exit(0)
# Prefer outputs_file_path, fallback to outputs_file_name (legacy). Capture raw string including ${...} placeholders.
m = re.search(r'\boutputs_file_path\s*=\s*"((?:[^"\\]|\\.)*)"', content) or re.search(r'\boutputs_file_name\s*=\s*"((?:[^"\\]|\\.)*)"', content)
if m:
    print(m.group(1).strip())
PY
}
OUTPUTS_FILE_PATH_RAW="$(read_outputs_file_path "${REPO_ROOT}/${VALUES_FILE}" 2>/dev/null)" || true
if [[ -z "${OUTPUTS_FILE_PATH_RAW}" ]]; then
  OUTPUTS_FILE_PATH_RAW="outputs.yaml"
fi
# Resolve dynamic variables (same logic as values file: deployment_prefix, env_name, org_name from ENV/ORG_NAME)
ENV_NAME="${ENV:-dev}"
ORG_NAME_VAL="${ORG_NAME:-}"
if [[ -n "${ORG_NAME_VAL}" ]]; then
  DEPLOYMENT_PREFIX_RESOLVED="divyam-${ORG_NAME_VAL}-${ENV_NAME}"
else
  DEPLOYMENT_PREFIX_RESOLVED="divyam-${ENV_NAME}"
fi
# Substitute Terragrunt-style placeholders in the path
OUTPUTS_FILE_PATH="${OUTPUTS_FILE_PATH_RAW}"
OUTPUTS_FILE_PATH="${OUTPUTS_FILE_PATH//\$\{local.deployment_prefix\}/${DEPLOYMENT_PREFIX_RESOLVED}}"
OUTPUTS_FILE_PATH="${OUTPUTS_FILE_PATH//\$\{local.env_name\}/${ENV_NAME}}"
OUTPUTS_FILE_PATH="${OUTPUTS_FILE_PATH//\$\{local.org_name\}/${ORG_NAME_VAL}}"
OUTPUTS_FILE_PATH="${OUTPUTS_FILE_PATH//\$\{deployment_prefix\}/${DEPLOYMENT_PREFIX_RESOLVED}}"
# Resolve relative to REPO_ROOT; ensure no leading slash
OUTPUTS_FILE_PATH="${OUTPUTS_FILE_PATH#/}"
OUT_FILE="${REPO_ROOT}/${OUTPUTS_FILE_PATH}"
# Format from extension: .json -> JSON, .yaml/.yml -> YAML, else YAML
case "${OUT_FILE}" in
  *.json) OUTPUT_FORMAT="json" ;;
  *.yaml) OUTPUT_FORMAT="yaml" ;;
  *.yml)  OUTPUT_FORMAT="yaml" ;;
  *)      OUTPUT_FORMAT="yaml" ; OUT_FILE="${OUT_FILE}.yaml" ;;
esac
TG_DIR_ABS="${REPO_ROOT}/${TG_DIR}"

if [[ ! -d "${TG_DIR_ABS}" ]]; then
  echo "Error: Layer directory not found: ${TG_DIR_ABS}"
  exit 1
fi

# Find all directories under TG_DIR that contain terragrunt.hcl and whose path contains CLOUD_PROVIDER
# (same filter as sample_deploy.sh: ./**/${CLOUD_PROVIDER})
module_dirs=()
while IFS= read -r -d '' f; do
  dir="$(dirname "${f}")"
  rel="${dir#${REPO_ROOT}/}"
  if [[ "${rel}" == *"${CLOUD_PROVIDER}"* ]]; then
    module_dirs+=("${dir}")
  fi
done < <(find "${TG_DIR_ABS}" -name "terragrunt.hcl" -print0 2>/dev/null)

# Sort for stable ordering
IFS=$'\n' read -d '' -r -a module_dirs <<< "$(printf '%s\n' "${module_dirs[@]}" | sort -u)" || true

merged_json="{}"
for dir in "${module_dirs[@]}"; do
  rel="${dir#${REPO_ROOT}/}"
  key="${rel//\//__}"
  out=$(cd "${dir}" && terragrunt output -json 2>/dev/null) || true
  if [[ -z "${out}" ]]; then
    continue
  fi
  merged_json="$(echo "${merged_json}" | jq -c --arg k "${key}" --argjson val "${out}" '.[$k] = $val')"
done

# Apply include/exclude from HCL locals.outputs_for_helm (optional)
read_hcl_outputs_for_helm() {
  local hcl_file="$1"
  python3 - "$hcl_file" << 'PY'
import re
import sys
import json

def extract_block(content, start_marker, open_br, close_br):
    idx = content.find(start_marker)
    if idx == -1:
        return None
    idx = content.find(open_br, idx)
    if idx == -1:
        return None
    start = idx + 1
    depth = 1
    for i in range(start, len(content)):
        if content[i] == open_br:
            depth += 1
        elif content[i] == close_br:
            depth -= 1
            if depth == 0:
                return content[start:i]
    return None

def extract_array(block, key):
    pattern = re.compile(r'\b' + re.escape(key) + r'\s*=\s*\[', re.IGNORECASE)
    m = pattern.search(block)
    if not m:
        return []
    start = m.end()
    depth = 1
    i = start
    while i < len(block):
        if block[i] == '[':
            depth += 1
        elif block[i] == ']':
            depth -= 1
            if depth == 0:
                inner = block[start:i]
                # Match quoted strings
                parts = re.findall(r'"([^"]*)"', inner)
                return parts
        i += 1
    return []

def main():
    path = sys.argv[1]
    try:
        with open(path) as f:
            content = f.read()
    except Exception:
        print(json.dumps({"include_modules": [], "exclude_modules": [], "include_outputs": [], "exclude_outputs": []}))
        return
    block = extract_block(content, "outputs_for_helm", "{", "}")
    if not block:
        print(json.dumps({"include_modules": [], "exclude_modules": [], "include_outputs": [], "exclude_outputs": []}))
        return
    result = {
        "include_modules": extract_array(block, "include_modules"),
        "exclude_modules": extract_array(block, "exclude_modules"),
        "include_outputs": extract_array(block, "include_outputs"),
        "exclude_outputs": extract_array(block, "exclude_outputs"),
    }
    print(json.dumps(result))

main()
PY
}

if [[ -f "${HCL_CONFIG_FILE}" ]]; then
  hcl_json="$(read_hcl_outputs_for_helm "${HCL_CONFIG_FILE}" 2>/dev/null)" || hcl_json=""
  if [[ -n "${hcl_json}" ]]; then
    include_modules="$(echo "${hcl_json}" | jq -c '.include_modules')"
    exclude_modules="$(echo "${hcl_json}" | jq -c '.exclude_modules')"
    include_outputs="$(echo "${hcl_json}" | jq -c '.include_outputs')"
    exclude_outputs="$(echo "${hcl_json}" | jq -c '.exclude_outputs')"

    # Filter by module path: key is like 0-foundation__1-vnet__azure, config path is 0-foundation/1-vnet/azure
    if [[ "${exclude_modules}" != "[]" ]]; then
      merged_json="$(echo "${merged_json}" | jq -c --argjson exc "${exclude_modules}" '
        to_entries | map(select((.key | gsub("__"; "/") | . as $path | ($exc | index($path)) == null))) | from_entries
      ')"
    fi
    if [[ "${include_modules}" != "[]" ]]; then
      merged_json="$(echo "${merged_json}" | jq -c --argjson inc "${include_modules}" '
        to_entries | map(select((.key | gsub("__"; "/") | . as $path | ($inc | index($path)) != null))) | from_entries
      ')"
    fi

    # Per-module: include/exclude output names (drop keys from each module's value object)
    if [[ "${exclude_outputs}" != "[]" || "${include_outputs}" != "[]" ]]; then
      merged_json="$(echo "${merged_json}" | jq -c --argjson inc "${include_outputs}" --argjson exc "${exclude_outputs}" '
        to_entries | map(
          .value as $v |
          if ($v | type) == "object" then
            .value = (
              $v | to_entries | map(
                select(
                  (if ($exc | length) > 0 then (.key | IN($exc[])) | not else true end) and
                  (if ($inc | length) > 0 then .key | IN($inc[]) else true end)
                )
              ) | from_entries
            )
          else . end
        ) | from_entries
      ')"
    fi
  fi
fi

# Write outputs to single file; format from extension
mkdir -p "$(dirname "${OUT_FILE}")"
if [[ -n "${merged_json}" && "${merged_json}" != "{}" ]]; then
  wrapped="$(echo "${merged_json}" | jq -c '{"terraform_outputs": .}')"
  if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
    echo "${wrapped}" > "${OUT_FILE}"
    echo "Wrote ${OUT_FILE} (JSON)"
  else
    if command -v ruby &>/dev/null; then
      echo "${wrapped}" | ruby -r json -r yaml -e "puts JSON.parse(STDIN.read).to_yaml" > "${OUT_FILE}"
      echo "Wrote ${OUT_FILE} (YAML)"
    else
      base="${OUT_FILE%.yaml}"; base="${base%.yml}"
      echo "${wrapped}" > "${base}.json"
      echo "No Ruby; wrote ${base}.json instead"
    fi
  fi
else
  echo "No outputs collected (no modules with state or filter excluded all)."
  if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
    echo '{"terraform_outputs":{}}' > "${OUT_FILE}"
  else
    echo "terraform_outputs: {}" > "${OUT_FILE}"
  fi
fi
