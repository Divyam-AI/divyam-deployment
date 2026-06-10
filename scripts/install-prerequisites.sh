#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# install-prerequisites.sh — install/verify the pinned toolchain this repo needs.
#
# Installs (and pins, where a version is fixed) the tools used across both phases:
#   OpenTofu 1.11.5      via tenv          (Phase 1 — IaC)
#   Terragrunt 0.99.4    via tenv          (Phase 1 — IaC; note the 0.99 `run` syntax)
#   Helmfile v1.4.4      pinned release    (Phase 2 — stack deploy)
#   helm-diff v3.7.0     helm plugin       (Phase 2 — `helmfile diff`)
#   Helm    (latest)     brew / get.helm   (Phase 2)
#   helm-dashboard       helm plugin       (Phase 2 — web UI: `helm dashboard`)
#   helm-tui             helm plugin       (Phase 2 — terminal UI: `helm tui`)
#   K9s     (latest)     brew / release    (cluster TUI)
#   jq, yq  (latest)                       (provider.yaml / outputs wrangling)
#
# It does NOT touch cloud auth — `az login` / `gcloud auth login` and cluster
# credential fetches are interactive and are run by you (see README / CLAUDE.md).
# Validate cloud creds afterwards with scripts/check_cloud_credentials.sh.
#
# Usage:
#   scripts/install-prerequisites.sh            # install anything missing, then verify
#   scripts/install-prerequisites.sh --check    # verify only; never install (CI-friendly, exits 1 if gaps)
#   scripts/install-prerequisites.sh --help
#
# Direct release downloads land in $INSTALL_BIN (default ~/.local/bin); make sure
# that dir is on your PATH. On macOS, Homebrew is used when available.
set -euo pipefail

# ---- pinned versions (keep in sync with CLAUDE.md "Tooling" table) ----
TOFU_VERSION="1.11.5"
TERRAGRUNT_VERSION="0.99.4"
HELMFILE_VERSION="1.4.4"
HELM_DIFF_VERSION="3.7.0"

CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  -h|--help) grep '^#' "$0" | grep -vE '^#(!|[[:space:]]*SPDX-)' | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "unknown arg: $1 (use --check or --help)" >&2; exit 2 ;;
esac

INSTALL_BIN="${INSTALL_BIN:-$HOME/.local/bin}"
mkdir -p "$INSTALL_BIN"

# ---- platform detection ----
OS="$(uname -s | tr 'A-Z' 'a-z')"          # darwin | linux
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) ARCH="$ARCH_RAW" ;;
esac
HAVE_BREW=0; if [[ "$OS" == "darwin" ]] && command -v brew >/dev/null; then HAVE_BREW=1; fi

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
GAPS=0
have() { command -v "$1" >/dev/null 2>&1; }
# ver_of <cmd> — best-effort semver from --version/version output, else "present"
ver_of() {
  local v; v="$("$1" --version 2>/dev/null || "$1" version 2>/dev/null || true)"
  v="$(printf '%s' "$v" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  printf '%s' "${v:-present}"
}
note() { echo "  $*"; }
ok()   { echo "${GRN}OK${RST}   $*"; }
miss() { echo "${RED}MISS${RST} $*"; GAPS=$((GAPS+1)); }
warn() { echo "${YLW}WARN${RST} $*"; }

# fetch <url> <dest> — download a file (curl or wget), make executable if a binary
fetch() {
  local url="$1" dest="$2"
  if have curl; then curl -fsSL "$url" -o "$dest"
  elif have wget; then wget -qO "$dest" "$url"
  else echo "need curl or wget to download $url" >&2; return 1; fi
}

require_install() {  # in --check mode we never install; just record the gap
  if [[ "$CHECK_ONLY" -eq 1 ]]; then return 1; fi
  return 0
}

# ---------------------------------------------------------------------------
# tenv — version manager for OpenTofu + Terragrunt
# ---------------------------------------------------------------------------
ensure_tenv() {
  if have tenv; then ok "tenv ($(tenv --version 2>/dev/null | head -1))"; return; fi
  if ! require_install; then miss "tenv (run without --check to install)"; return; fi
  if [[ "$HAVE_BREW" -eq 1 ]]; then
    brew install tenv
  else
    note "installing tenv from GitHub releases into $INSTALL_BIN"
    local tag tar
    tag="$(fetch "https://api.github.com/repos/tofuutils/tenv/releases/latest" /dev/stdout | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)"
    tar="$(mktemp)"
    fetch "https://github.com/tofuutils/tenv/releases/download/${tag}/tenv_${tag}_${OS^}_${ARCH}.tar.gz" "$tar" \
      || fetch "https://github.com/tofuutils/tenv/releases/download/${tag}/tenv_${tag}_$(uname -s)_${ARCH}.tar.gz" "$tar"
    tar -xzf "$tar" -C "$INSTALL_BIN" tenv tofu terragrunt terraform 2>/dev/null || tar -xzf "$tar" -C "$INSTALL_BIN"
    chmod +x "$INSTALL_BIN"/tenv "$INSTALL_BIN"/tofu "$INSTALL_BIN"/terragrunt 2>/dev/null || true
    rm -f "$tar"
  fi
  have tenv && ok "tenv installed" || miss "tenv install failed"
}

# ensure a tenv-managed tool is installed at the pinned version and set as default
ensure_tenv_tool() {  # <tool> <version>
  local tool="$1" want="$2" cur=""
  if have "$tool"; then cur="$($tool --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"; fi
  if [[ "$cur" == "$want" ]]; then ok "$tool $cur"; return; fi
  if ! have tenv; then miss "$tool $want (tenv missing)"; return; fi
  if ! require_install; then miss "$tool $want (have: ${cur:-none})"; return; fi
  tenv "$tool" install "$want"
  tenv "$tool" use "$want" >/dev/null 2>&1 || true
  cur="$($tool --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ "$cur" == "$want" ]] && ok "$tool $cur" || warn "$tool installed but default is ${cur:-unknown}; run: tenv $tool use $want"
}

# ---------------------------------------------------------------------------
# Helm (latest)
# ---------------------------------------------------------------------------
ensure_helm() {
  if have helm; then ok "helm ($(helm version --short 2>/dev/null))"; return; fi
  if ! require_install; then miss "helm"; return; fi
  if [[ "$HAVE_BREW" -eq 1 ]]; then brew install helm
  else
    local s; s="$(mktemp)"; fetch "https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3" "$s"
    HELM_INSTALL_DIR="$INSTALL_BIN" USE_SUDO=false bash "$s"; rm -f "$s"
  fi
  have helm && ok "helm installed" || miss "helm install failed"
}

# ---------------------------------------------------------------------------
# Helmfile (pinned v1.4.4)
# ---------------------------------------------------------------------------
ensure_helmfile() {
  local cur=""
  if have helmfile; then cur="$(helmfile version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"; fi
  if [[ "$cur" == "$HELMFILE_VERSION" ]]; then ok "helmfile $cur"; return; fi
  if [[ -n "$cur" ]]; then warn "helmfile $cur present, repo pins $HELMFILE_VERSION"; fi
  if ! require_install; then [[ -n "$cur" ]] || miss "helmfile $HELMFILE_VERSION"; return; fi
  local tar; tar="$(mktemp)"
  fetch "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz" "$tar"
  tar -xzf "$tar" -C "$INSTALL_BIN" helmfile; chmod +x "$INSTALL_BIN/helmfile"; rm -f "$tar"
  "$INSTALL_BIN/helmfile" version >/dev/null 2>&1 && ok "helmfile $HELMFILE_VERSION installed -> $INSTALL_BIN" || miss "helmfile install failed"
}

# ---------------------------------------------------------------------------
# helm-diff plugin (pinned v3.7.0) — required by `helmfile diff`
# ---------------------------------------------------------------------------
ensure_helm_diff() {
  if ! have helm; then miss "helm-diff (helm missing)"; return; fi
  if helm plugin list 2>/dev/null | grep -qi '^diff'; then ok "helm-diff plugin (installed)"; return; fi
  if ! require_install; then miss "helm-diff plugin v$HELM_DIFF_VERSION"; return; fi
  helm plugin install https://github.com/databus23/helm-diff --version "v${HELM_DIFF_VERSION}" --verify=false \
    && ok "helm-diff v$HELM_DIFF_VERSION installed" || miss "helm-diff install failed"
}

# ---------------------------------------------------------------------------
# Helm dashboard (Komodor) — web UI for releases; invoked as `helm dashboard`
# ---------------------------------------------------------------------------
ensure_helm_dashboard() {
  if ! have helm; then miss "helm-dashboard (helm missing)"; return; fi
  if helm plugin list 2>/dev/null | grep -qi '^dashboard'; then ok "helm-dashboard plugin (installed)"; return; fi
  if ! require_install; then miss "helm-dashboard plugin"; return; fi
  # Pinned tag + --verify=false: upstream publishes NO .prov signatures, so helm 4's plugin
  # verification can never pass — the pin is the available supply-chain control (no moving default
  # branch). Drop --verify=false if upstream ever signs releases; bump the tag deliberately.
  helm plugin install https://github.com/komodorio/helm-dashboard.git --version v2.1.1 --verify=false \
    && ok "helm-dashboard installed (run: helm dashboard)" || miss "helm-dashboard install failed"
}

# ---------------------------------------------------------------------------
# helm-tui (pidanou) — terminal UI for releases; invoked as `helm tui`
# ---------------------------------------------------------------------------
ensure_helm_tui() {
  if ! have helm; then miss "helm-tui (helm missing)"; return; fi
  if helm plugin list 2>/dev/null | grep -qi '^tui'; then ok "helm-tui plugin (installed)"; return; fi
  if ! require_install; then miss "helm-tui plugin"; return; fi
  # Pinned tag + --verify=false: same rationale as helm-dashboard above (unsigned upstream).
  helm plugin install https://github.com/pidanou/helm-tui --version v0.6.0 --verify=false \
    && ok "helm-tui installed (run: helm tui)" || miss "helm-tui install failed"
}

# ---------------------------------------------------------------------------
# K9s + jq + yq (latest) and a couple of soft checks
# ---------------------------------------------------------------------------
ensure_brew_or_release() {  # <cmd> <brew-formula> <release-url-template-with-{os}{arch}> [is-tarball:member]
  local cmd="$1" formula="$2" url="$3" member="${4:-}"
  if have "$cmd"; then ok "$cmd $(ver_of "$cmd")"; return; fi
  if ! require_install; then miss "$cmd"; return; fi
  if [[ "$HAVE_BREW" -eq 1 ]]; then brew install "$formula"
  else
    url="${url//\{os\}/$OS}"; url="${url//\{arch\}/$ARCH}"
    if [[ -n "$member" ]]; then
      local tar; tar="$(mktemp)"; fetch "$url" "$tar"; tar -xzf "$tar" -C "$INSTALL_BIN" "$member"; rm -f "$tar"
    else
      fetch "$url" "$INSTALL_BIN/$cmd"
    fi
    chmod +x "$INSTALL_BIN/$cmd" 2>/dev/null || true
  fi
  have "$cmd" && ok "$cmd installed" || miss "$cmd install failed"
}

echo "== Divyam deployment prerequisites =="
echo "   os=$OS arch=$ARCH  brew=$([[ $HAVE_BREW -eq 1 ]] && echo yes || echo no)  mode=$([[ $CHECK_ONLY -eq 1 ]] && echo check-only || echo install)"
echo "   install-bin=$INSTALL_BIN"
echo

ensure_tenv
ensure_tenv_tool tofu "$TOFU_VERSION"
ensure_tenv_tool terragrunt "$TERRAGRUNT_VERSION"
ensure_helm
ensure_helmfile
ensure_helm_diff
ensure_helm_dashboard
ensure_helm_tui
ensure_brew_or_release k9s k9s "https://github.com/derailed/k9s/releases/latest/download/k9s_{os}_{arch}.tar.gz" k9s
ensure_brew_or_release jq jq "https://github.com/jqlang/jq/releases/latest/download/jq-{os}-{arch}"
ensure_brew_or_release yq yq "https://github.com/mikefarah/yq/releases/latest/download/yq_{os}_{arch}"

# soft checks — installed out-of-band (cloud CLIs, kubectl, python3 for zenduty.py)
echo
echo "-- not installed by this script (install/verify yourself) --"
have kubectl && ok "kubectl ($(kubectl version --client -o json 2>/dev/null | grep -oE '"gitVersion": *"[^"]+"' | head -1 | cut -d'"' -f4))" || warn "kubectl not found (needed for Phase 2)"
have python3 && ok "python3 ($(python3 --version 2>&1))" || warn "python3 not found (needed for scripts/zenduty.py)"
have gcloud && ok "gcloud present" || note "gcloud not found — install only if deploying to GCP"
have az && ok "az present" || note "az not found — install only if deploying to Azure"

echo
case ":$PATH:" in *":$INSTALL_BIN:"*) ;; *)
  [[ "$HAVE_BREW" -eq 1 ]] || warn "add $INSTALL_BIN to your PATH:  export PATH=\"$INSTALL_BIN:\$PATH\"" ;;
esac

if [[ "$GAPS" -gt 0 ]]; then
  echo "${RED}$GAPS prerequisite(s) missing or unpinned.${RST}"
  [[ "$CHECK_ONLY" -eq 1 ]] && echo "Run without --check to install them."
  exit 1
fi
echo "${GRN}All prerequisites satisfied.${RST}"
echo "Next: scripts/gen-tf-env.sh (secrets) -> scripts/check_cloud_credentials.sh (creds) -> terragrunt (see README)."
