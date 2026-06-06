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
- `artifacts.yaml` / `releases/<VERSION>-artifacts.yaml` — chart versions + image tags.

## ARTIFACTS_VERSION resolution (which artifacts file wins)
1. `-a/--artifacts-version <v>` (or `$ARTIFACTS_VERSION`) → `k8s/releases/<v>-artifacts.yaml` (error if missing).
2. else a local `artifacts.yaml` in the values dir (dev).
3. else the latest `releases/*-artifacts.yaml` (sorted `yy.mm.dd`).
Example: `make k8s -- install -a 26.04.01-rc1`.

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
