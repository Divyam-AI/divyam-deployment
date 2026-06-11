# CLIs: iac.sh + k8s.sh + Makefile

**Entrypoint:** run every subcommand below as `make iac -- <subcommand> [opts]` /
`make k8s -- <subcommand> [opts]` (the `--` passes flags through). These forward verbatim to
`./scripts/iac.sh` / `./scripts/k8s.sh`, which are identical and callable directly **without** `--`
(what the slash commands and CI use). Both print the exact command they run and accept `-n` (dry-run)
and `-y` (skip confirms). Per-subcommand help: `make iac -- help` / `make k8s -- help`.

## iac.sh subcommands — Phase 1 (Terragrunt), run as `make iac -- <subcommand>`

| Subcommand | What it runs (in `iac/<layer1>[/<layer2>]`) |
|------------|----------------------------------------------|
| `config` | persists `-c`/`-e` to `.iac.conf`; with no flags, prints current |
| `secrets` | `scripts/gen-tf-env.sh --cloud <c> --env <e>` → `iac/values/secrets.env` |
| `creds` | `CLOUD_PROVIDER=<c> scripts/check_cloud_credentials.sh` |
| `init` | `terragrunt init -reconfigure --all <filters>` |
| `plan` | `terragrunt run plan --all <filters>` |
| `apply` | `terragrunt run apply --all <filters>` |
| `show` | `terragrunt show --all <filters>` |
| `destroy` | flips `prevent_destroy→false`, `run plan -destroy` preview, type-to-confirm the layer name, then `terragrunt run destroy --all <filters>`; prints how to restore |
| `protect` | flips `prevent_destroy→true`, then `terragrunt run apply --all <filters>` |

Options: `-l/--layer <layer1[.layer2]>`, `-c/--cloud <gcp|azure>`, `-e/--env <name>`,
`-f/--filter <glob>` (override the computed filter), `-y/--yes`, `-n/--dry-run`, `-h/--help`.

`<filters>` = the 4-filter cloud union (see `terragrunt-tofu.md`): `--filter ./<cloud>`,
`--filter ./<cloud>/**`, `--filter ./**/<cloud>`, `--filter ./**/<cloud>/**`. `-f` replaces all four.

## k8s.sh subcommands — Phase 2 (Helmfile), run as `make k8s -- <subcommand>`

| Subcommand | What it runs (from the values dir, `-f <helmfile>`) |
|------------|------------------------------------------------------|
| `config` | persists `-d`/`-e`/`-a` to `.k8s.conf`; with no flags, prints current |
| `kubeconfig` (alias `auth`) | resolve cluster identifiers, then GCP `gcloud container clusters get-credentials …` or Azure (`az login --service-principal` if needed) `az aks get-credentials …` — see `clouds.md` |
| `diff` | `helmfile … <sel> diff` |
| `install` | auto-`diff` → confirm → `helmfile … <sel> sync` (FIRST install; installs ALL releases) |
| `upgrade` | auto-`diff` → confirm → `helmfile … <sel> apply` (routine; only changed) |
| `delete` (alias `destroy`) | type-to-confirm → `helmfile … <sel> destroy` |
| `template` | `helmfile … <sel> template` (append `-- --debug` to pass helm flags) |
| `status` (alias `ls`) | `helm ls -A`, then `--tui` → `helm tui`, `--dashboard` → `helm dashboard`, else interactive prompt |

Options: `-l/--release <chart>` (→ `-l name=<chart>-<env>`; a value with `=` like `name=foo`/`tier=db`
is passed raw; omit → whole stack), `-f/--filter <sel>` (raw helmfile selector override),
`-e/--env <name>`, `-d/--values-dir <dir>` (default `k8s/helm-values`), `-a/--artifacts-version <v>`,
`--tui`, `--dashboard`, `-y/--yes`, `-n/--dry-run`, `-h/--help`, and the kubeconfig-only flags
`-c/--cloud`, `--cluster`, `--project`, `--region`, `--zone`, `--resource-group`, `--login`, `--no-tf`.
`--` forwards the rest to helmfile.

## Makefile

| Target | Runs |
|--------|------|
| `make iac -- <args>` | `./scripts/iac.sh <args>` |
| `make k8s -- <args>` | `./scripts/k8s.sh <args>` |
| `make prereqs` | `scripts/install-prerequisites.sh` |
| `make prereqs-check` | `scripts/install-prerequisites.sh --check` |
| `make help` | targets + usage |

**The `--` is required** before CLI args (make reserves `-l/-c/-e/-n`; `--long` errors). Examples:
`make iac -- plan -l 1-platform.1-k8s -c gcp`, `make k8s -- upgrade -l router`. Forgetting `--` fails
safe (the CLI errors on the missing flag rather than acting wrongly).

## Helper scripts (called by the CLIs; usable directly)

- `scripts/gen-tf-env.sh --cloud <c> --env <e> [--region R --zone Z --out FILE --force]` — writes
  `iac/values/secrets.env` (TF_VAR_* + config; randomises safe secrets, leaves real ones as `FILL`).
- `scripts/check_cloud_credentials.sh` (needs `CLOUD_PROVIDER`) — GCP ADC/SA-key or Azure SP/az-login pre-flight.
- `scripts/install-prerequisites.sh [--check]` — install/verify pinned tools (`prerequisites.md`).
- `scripts/set-prevent-destroy.sh -l <layer> -c <cloud> --set true|false [--run <verb>] | --restore` —
  flips `prevent_destroy` across a module (backups `*.pdbak`); used by `make iac -- destroy`/`protect`.
- `scripts/write-outputs-yaml.sh [LAYER CLOUD …]` — collects `terragrunt output` across a layer into YAML/JSON for Helm.
- `iac/scripts/migration.sh` — one-time Terraform state move (1-k8s → 2-monitoring) for the observability refactor.
