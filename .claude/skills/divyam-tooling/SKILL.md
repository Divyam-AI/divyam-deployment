---
name: divyam-tooling
description: >
  How to drive THIS repo's tooling — the Makefile (`make iac -- …` / `make k8s -- …`), the two CLIs
  scripts/iac.sh (Terragrunt) and scripts/k8s.sh (Helmfile), the helper scripts, and the underlying
  tools (terragrunt/tofu, helm/helmfile, kubectl, gcloud/az). Use to look up the exact command, flag,
  selector, filter, or pinned version before running anything. TRIGGER on: "how do I run …", which
  flag/selector/filter to use, `make iac`/`make k8s`/iac.sh/k8s.sh usage, the `--` rule, layer1.layer2,
  `-l name=<chart>`, terragrunt 0.99 `run` syntax, ARTIFACTS_VERSION, get-credentials, pinned tool versions.
  Also TRIGGER on debugging a failed deploy: a `make k8s -- install/upgrade` (helmfile sync/apply)
  error, a release stuck/rolled back (`context deadline exceeded`), ExternalSecret/SecretStore not
  resolving, `provider.yaml`/values-dir not found, or `needs`-ordering questions → `references/debugging.md`.
---

# Divyam tooling

The **Makefile is the entrypoint**. Two workflow commands cover everything; both always print the exact
`terragrunt`/`helmfile`/`gcloud`/`az` command they run and support `-n/--dry-run`.

## The entrypoint

- **Phase 1 (infra):** `make iac -- <cmd> [opts]` — Terragrunt/OpenTofu layers.
- **Phase 2 (stack):** `make k8s -- <cmd> [opts]` — Helmfile releases.
- Setup (no args): `make prereqs`, `make prereqs-check`, `make help`.

> The **`--` is required** before args — without it `make` swallows `-l/-c/-e`-style flags (and `--long`
> errors). `make iac`/`make k8s` forward verbatim to `./scripts/iac.sh` / `./scripts/k8s.sh`, which are
> identical and callable directly **without** `--` — that's what the slash commands and CI use, and what
> you run when you need per-subcommand help: `./scripts/iac.sh help`, `./scripts/k8s.sh help`. Treat the
> scripts as the implementation; treat `make iac/k8s --` as the door. Don't invent flags — check `help`.

## Conventions shared by both CLIs

- **Standard args:** short `-x`, long `--xxx`, and `--xxx=value` all work.
- **Remembered config:** `make iac -- config -c <cloud> -e <env>` → `.iac.conf`; `make k8s -- config -d <dir> -e <env> -a <ver>` → `.k8s.conf` (both gitignored, chmod 600). Later commands don't need the flags again.
- **Precedence:** CLI flag > pre-existing env var > `.iac.conf`/`.k8s.conf` > file default.
- **Dry-run:** `-n` prints the command (+ `(dry-run: not executed)`); **`-y`** skips confirmations (automation only).
- **Secrets:** the Phase-1 flow auto-sources `iac/values/secrets.env` (generate with `make iac -- secrets`). Never print its contents.

## Reference guide — load the file for the task

| Topic | Reference | Load when |
|-------|-----------|-----------|
| Full iac.sh + k8s.sh subcommand/flag matrix, Makefile passthrough, exact emitted commands | `references/clis.md` | choosing a command/flag, or unsure what a subcommand runs |
| Terragrunt 0.99 `run` syntax, OpenTofu 1.11.5, the 4-filter cloud union, `layer1.layer2`, state caveats, `prevent_destroy` | `references/terragrunt-tofu.md` | running/reasoning about iac.sh or raw terragrunt |
| helmfile diff/sync/apply/destroy/template, values layering, `ARTIFACTS_VERSION`, `-l name=<chart>-<env>`, helm-diff/helm-tui/helm-dashboard | `references/helm-helmfile.md` | running/reasoning about k8s.sh or raw helmfile |
| kubectl verification commands + what's allow-listed vs `ask` | `references/kubectl.md` | verifying the cluster/stack, debugging pods |
| Deployment-failure playbook: `needs` ordering, atomic timeouts, ExternalSecret/secrets chain, provider.yaml/values-dir resolution, transient fetch errors | `references/debugging.md` | a `make k8s -- install/upgrade` fails or releases don't go healthy |
| GCP vs Azure: project vs resource-group, auth, `get-credentials`, GKE/AKS, service mapping | `references/clouds.md` | anything cloud-specific, kubeconfig, creds |
| Pinned tool versions + install; **Helm 4 breaks helm-diff/helmfile — use Helm 3** | `references/prerequisites.md` | setting up a machine, version mismatch, `make prereqs`, `plugin "diff" exited with error` |
| Read cloud ground truth WITHOUT az/gcloud — SP/ADC token → ARM/GCP REST (list clusters, inspect a subnet, OIDC issuer, compare federated creds) | `references/ground-truth-rest.md` | az/gcloud absent, "how many clusters exist", "what's in the app-gw subnet", verifying a console/handoff action |
| Adopt pre-existing resources & recover state: `already exists` → import; the import dep-mock whitelist trick; purge-protected Key Vault; delete+recreate orphaned UAMIs; rebind federated creds after a cluster recreate | `references/recovery-and-imports.md` | a prior/lost-state deployment, `already exists`, broken workload identity, dual state |
| Known blockers + fixes: env allowlist + org/env name-length (Azure 24-char, now validated), NAP NodePools missing (`0-nap_configs`), Kafka RF vs broker count, App-GW subnet collision, the state-key filename fork | `references/known-gotchas.md` | a deploy stalls/fails in a way that matches a known trap, or an env/org name is rejected |

## Quick map: intent → command

| Intent | Command |
|--------|---------|
| Remember cloud+env | `make iac -- config -c gcp -e dev` |
| Generate secrets file | `make iac -- secrets` (→ `iac/values/secrets.env`) |
| Validate cloud creds | `make iac -- creds` |
| Plan / apply a layer | `make iac -- plan -l 1-platform.1-k8s` / `make iac -- apply -l 1-platform` |
| Tear a layer down (guarded) | `make iac -- destroy -l 0-foundation` |
| Re-harden prevent_destroy | `make iac -- protect -l 2-app.0-divyam_secrets` |
| Fetch kubeconfig (auth) | `make k8s -- kubeconfig` |
| Preview stack changes | `make k8s -- diff` |
| First install / upgrade | `make k8s -- install -a <ver>` / `make k8s -- upgrade -l router` |
| Release status (+ TUI/web) | `make k8s -- status [--tui\|--dashboard]` |
| Install/verify toolchain | `make prereqs` / `make prereqs-check` |

(Equivalent without `make`: drop the `make iac --` / `make k8s --` prefix and run `./scripts/iac.sh …` /
`./scripts/k8s.sh …` directly — same subcommands and flags.)

## Guardrails
- Authoritative source is `scripts/iac.sh` / `scripts/k8s.sh` (and their `help`); references here mirror
  them — if they ever disagree, the scripts win and the reference should be corrected.
- Don't run mutating verbs (`apply`/`sync`/`upgrade`/`destroy`/`delete`) without a reviewed `plan`/`diff`.
- `apply`/`destroy`/`delete`/`import` and `kubectl delete/apply` prompt by policy (`.claude/settings.json` `ask`).
