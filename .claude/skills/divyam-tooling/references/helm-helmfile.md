# Helm + Helmfile (Phase 2)

Pinned: **Helmfile v1.4.4**, **helm-diff v3.7.0**, Helm latest, plus optional **helm-tui**
(`pidanou/helm-tui` → `helm tui`) and **helm-dashboard** (`komodorio/helm-dashboard` → `helm dashboard`).
`make k8s -- …` (which forwards to `scripts/k8s.sh`) drives `k8s/helmfile.yaml.gotmpl`; you rarely call helmfile directly.

## Verbs (and the make command that wraps each)
| helmfile | command | When |
|----------|---------|------|
| `diff` | `make k8s -- diff` | ALWAYS before a change — preview |
| `sync` | `make k8s -- install` | **FIRST install only** — installs ALL releases, can restart pods |
| `apply` | `make k8s -- upgrade` | routine — only changed releases |
| `destroy` | `make k8s -- delete` | uninstall (type-to-confirm) |
| `template` | `make k8s -- template` | render manifests locally (`-- --debug` for helm flags) |
| (`helm ls -A`) | `make k8s -- status` | list releases; `--tui`/`--dashboard` for detail |

`make k8s -- install`/`upgrade` auto-run `diff` first and ask to proceed (unless `-y`/`-n`).

## Values layering (merge priority, highest wins)
`config.yaml` > `resources.yaml` > `artifacts.yaml`, all in the values dir (default `k8s/helm-values`,
or `-d`/`HELMFILE_VALUES_DIR`). `provider.yaml` (written by Phase 1 `3-export_details`) supplies global
platform/env/secrets config.
- `provider.yaml` — **required**, from Terraform. Carries `environment`, `platform.provider`, DB, ingress, pull-secret config.
- `resources.yaml` — **required**, per-chart CPU/mem/storage/replicas/nodeSelector; set `enabled: false` to skip a chart.
- `config.yaml` — optional local overrides (highest priority).
- `artifacts.yaml` / `releases/<channel>/<id>-artifacts.yaml` — chart versions + image tags (+ a scalar
  `release:` block, which the helmfile `unset`s). Full contract: `k8s/releases/VERSIONING.md`.

## Artifacts channel/version resolution (which artifacts file wins)
Channels live under `releases/{stable,nightly}/`; each has a `latest` pointer file. Flags: `-C/--channel
<stable|nightly>` → `ARTIFACTS_CHANNEL`, `-a/--artifacts-version <id|latest>` → `ARTIFACTS_VERSION`.
1. `ARTIFACTS_CHANNEL` set → `releases/<channel>/<ver|latest>-artifacts.yaml` (`latest` = the
   `<channel>/latest` pointer, else newest by `sort -V`).
2. else only `ARTIFACTS_VERSION` set → `releases/<v>-artifacts.yaml` (legacy flat) → `stable/<v>` → `nightly/<v>`.
3. else local `artifacts.yaml` in the values dir (dev) → `stable/latest` → legacy newest (`sort -V`).
Examples: `make k8s -- install -C stable` · `-C stable -a 1.0.0` · `-C nightly -a latest` ·
legacy `-a 26.04.01-rc1` (still resolves). **Gotcha:** channel/version must be plain tokens (no `=`) —
`make` would otherwise eat `name=value` as a variable; that's why the older flat ids use `-rcN`, not `=`.

## Release/namespace naming + selection
- Release name = `<chart>-<env>`; namespace = `<chart-or-group>-<env>-ns`. `<env>` comes from
  `provider.yaml` `environment` (or `-e`).
- Single chart: `make k8s -- <verb> -l <chart>` → `helmfile -l name=<chart>-<env>` (e.g. `upgrade -l router` → `name=router-prod`).
- A `-l` value containing `=` (e.g. `name=mysql-prod`, `tier=db`) is passed as a raw label.
- `-f/--filter <sel>` overrides with a raw helmfile selector. Omit `-l` → whole stack.

## Safety
- Never `sync` after the first install — use `upgrade`. Always `diff` first.
- `kubectl delete/apply` and destructive helmfile ops prompt by policy; `helm ls`/`version`/`plugin list` are allow-listed.

> For generic Kubernetes manifest/Helm chart authoring use `devops-engineer`; this file is about
> operating the existing Divyam Helmfile.
