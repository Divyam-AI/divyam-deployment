# Prerequisites / pinned toolchain

Install or verify with the Makefile — these have no args so `make` is the right entry point:
```
make prereqs          # install anything missing, then verify
make prereqs-check    # verify only; non-zero exit if gaps (CI-friendly)
```
Backed by `scripts/install-prerequisites.sh` (`--check` for verify-only). Direct downloads land in
`~/.local/bin` (override `INSTALL_BIN`); on macOS Homebrew is used when present.

## Pinned versions (keep in sync with CLAUDE.md "Tooling")
| Tool | Version | Install |
|------|---------|---------|
| OpenTofu | 1.11.5 | `tenv tofu install 1.11.5` |
| Terragrunt | 0.99.4 | `tenv terragrunt install 0.99.4` (note 0.99 `run` syntax) |
| Helmfile | v1.4.4 | pinned GitHub release |
| helm-diff | v3.7.0 | `helm plugin install https://github.com/databus23/helm-diff --version v3.7.0` |
| Helm | latest | brew / get.helm.sh |
| helm-dashboard | latest | `helm plugin install https://github.com/komodorio/helm-dashboard.git` → `helm dashboard` |
| helm-tui | latest | `helm plugin install https://github.com/pidanou/helm-tui` → `helm tui` |
| K9s | latest | brew / GitHub release |
| jq, yq | latest | brew / GitHub release |

## Not installed by the script (you install/verify; cloud login is interactive)
- `kubectl` (Phase 2), `gcloud` / `az` (cloud CLIs), `python3` (for `scripts/zenduty.py`).
- `make prereqs-check` reports these as soft checks but won't install them.

## Order of a fresh setup
1. `make prereqs` → 2. install `kubectl` + the cloud CLI you need → 3. user runs `az login` /
`gcloud auth login` → 4. `make iac -- config -c <cloud> -e <env>` → `make iac -- secrets` (fill the
`FILL` values in `iac/values/secrets.env`) → `make iac -- creds`.
