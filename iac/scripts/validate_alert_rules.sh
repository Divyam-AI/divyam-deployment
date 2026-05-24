#!/usr/bin/env bash
# Validate 2-app/2-alerts/common/rules/*.json structure (CI-friendly).
set -euo pipefail

RULES_DIR="$(cd "$(dirname "$0")/../2-app/3-alerts/common/rules" && pwd)"
FAILED=0

for f in "$RULES_DIR"/*.json; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  if ! python3 - "$f" <<'PY'; then
import json, sys
path = sys.argv[1]
with open(path) as fp:
    data = json.load(fp)
if "rules" not in data or not isinstance(data["rules"], list):
    raise SystemExit("missing rules[] array")
for r in data["rules"]:
    if "alert" not in r or "expr" not in r:
        raise SystemExit(f"rule missing alert or expr: {r}")
    if "severity" not in r:
        raise SystemExit(f"rule missing severity: {r.get('alert')}")
print(f"ok: {path} ({len(data['rules'])} rules)")
PY
    echo "FAIL: $base" >&2
    FAILED=1
  fi
done

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
echo "All alert rule files validated."
