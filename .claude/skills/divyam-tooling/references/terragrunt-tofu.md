# Terragrunt + OpenTofu (Phase 1)

Pinned: **OpenTofu 1.11.5**, **Terragrunt 0.99.4** (installed via `tenv`; see `prerequisites.md`).
You rarely call these directly — `scripts/iac.sh` does — but you must understand what it emits.

## Terragrunt 0.99 `run` syntax
0.99 moved IaC verbs under `run`:
- `terragrunt run plan`  (not `terragrunt plan`)
- `terragrunt run apply`
- `terragrunt run destroy`
- `terragrunt init -reconfigure --all --filter <glob>` (explicit `--all`)
- `terragrunt show --all --filter <glob>`

`iac.sh` runs these with `--all` over a target directory you `cd` into.

## Layer addressing — `layer1[.layer2]`
- `layer1` = a dir under `iac/` (`0-foundation`, `1-platform`, `2-app`). `layer2` = a sub-unit dir
  (`1-k8s`, `2-monitoring`, `2-alerts`, …). `iac.sh` `cd`s into `iac/<layer1>[/<layer2>]` and runs
  `--all`. Omitting `.layer2` targets the whole layer.
- **Ordering inside a layer is automatic** via the terragrunt dependency DAG — e.g. `2-monitoring`
  declares a dependency on `1-k8s`, so `apply -l 1-platform` provisions the cluster before monitoring.
  No manual two-step needed (you *may* still target `-l 1-platform.1-k8s` then `-l 1-platform.2-monitoring`).

## The 4-filter cloud union (why it looks redundant)
A layer holds both clouds' units side by side, and the cloud token sits at different depths
(`1-k8s/gcp` = leaf; `2-app/2-alerts/gcp/alerts/datadog` = ancestor). Terragrunt's `**` matches
**one-or-more** segments (never zero), so no single glob selects every unit. `iac.sh` therefore emits
the verified-complete **union of four** (terragrunt ORs multiple `--filter`):
```
--filter ./<cloud> --filter ./<cloud>/** --filter ./**/<cloud> --filter ./**/<cloud>/**
```
This is correct for every layer/cloud. Override with `-f/--filter <glob>` only for irregular cases
(e.g. the cloud-agnostic `2-alerts/datadog` units when `datadog.enabled=true`).

## State caveats (read before destroy/re-apply)
- **`0-foundation` uses LOCAL state** — do NOT blindly re-`apply`/`destroy`; coordinate on state
  location. `1-platform`/`2-app` use **remote** state (the bucket/account from `2-terraform_state_blob_storage`).
- `TG_USE_LOCAL_BACKEND=1` is debug-only.
- Config flows via `get_env(...)` from `iac/values/defaults.hcl` (no `.tfvars` are loaded). `iac.sh`
  auto-sources `iac/values/secrets.env` so `TF_VAR_*` + `CLOUD_PROVIDER/ENV/REGION/ZONE/ORG_NAME/…` are present.

## prevent_destroy (destroy safety)
Critical resources (resource groups/projects, VNets/VPCs, the TF state bucket, secret vaults) carry
`lifecycle { prevent_destroy = true }`, which blocks `terragrunt destroy`. `make iac -- destroy` calls
`scripts/set-prevent-destroy.sh --set false` first (backups `*.pdbak`), previews, type-confirms, then
destroys; restore with `make iac -- protect` (or `scripts/set-prevent-destroy.sh … --restore` / `git
checkout`). `make iac -- protect` does the reverse (`--set true` → apply) to re-harden.

## Troubleshooting quick hits
- "already exists" → import the resource or set `create = false` and fill the existing name in the
  values file. `0-apis` "already exists" is safe to ignore.
- Empty plan / wrong scope → check the filter actually matched units (`make iac -- show -l <layer> -n` to see
  the command; or `terragrunt list --filter …`).
- Stale cache → `find . -type d -name .terragrunt-cache -exec rm -rf {} +`.

> For deeper IaC-correctness/hallucination guards (identity churn, blast radius, secret exposure) use
> the `terrashark` skill; for generic Terraform module/state questions, `terraform-engineer`.
