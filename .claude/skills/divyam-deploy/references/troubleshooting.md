# Troubleshooting the deploy

Stop and diagnose rather than forcing a command. Common failures and recovery:

## Phase 1 (terragrunt / iac.sh)
- **"already exists"** on a resource → either `terragrunt import` it, or set `create = false` in the
  values file and fill in the existing resource's name. `0-apis` "already exists" is safe to ignore.
- **Empty plan / nothing matched / wrong scope** → the cloud filter may have missed the unit. Preview
  the exact command with `make iac -- <verb> -l <layer> -n`; for irregular units (e.g. `2-alerts/datadog`
  when `datadog.enabled=true`) pass an explicit `-f/--filter`. See `divyam-tooling/references/terragrunt-tofu.md`.
- **"no layer set" / unexpected arg from `make`** → you forgot the `--`: use `make iac -- <args>`.
- **State confusion / `0-foundation`** → it's LOCAL state; do not re-apply/destroy blindly. Coordinate;
  don't relocate state casually. Clear stale cache: `find . -type d -name .terragrunt-cache -exec rm -rf {} +`.
- **Auth failures** → `make iac -- creds`. GCP: re-run `gcloud auth application-default login` or fix
  `GOOGLE_APPLICATION_CREDENTIALS`. Azure: ensure all four `ARM_*` are exported (or `az login`).
- **destroy blocked by prevent_destroy** → expected; `make iac -- destroy` flips it to false first. If you
  edited flags manually, restore with `scripts/set-prevent-destroy.sh -l <layer> -c <cloud> --restore`
  or `git checkout` (look for stray `*.pdbak`).

## Phase 1 → Phase 2 handoff
- **No `k8s/helm-values/provider.yaml`** → `2-app/3-export_details` didn't run; apply `-l 2-app` (and
  ensure 1-platform succeeded). Don't start Phase 2 without it.

## Phase 2 (helmfile / k8s.sh)
- **`make k8s -- kubeconfig` can't resolve cluster/RG/project** → cluster not applied yet, or terragrunt
  state unreachable; pass `--cluster/--project/--region/--resource-group` (and `--no-tf`) explicitly.
- **`kubectl get ns` fails after kubeconfig** → wrong context (`kubectl config current-context`),
  network path to control plane (run from the bastion / in-VPC runner), or expired creds.
- **`ImagePullBackOff`** → registry pull secret missing: `TF_VAR_divyam_artifactory_docker_auth` must
  point to a valid cred file in Phase 1, and nodes/runner must reach the auth-restricted registry.
- **Pending pods** → `kubectl describe pod …`: scheduling/`nodeSelector`/resources — adjust
  `resources.yaml`, then `make k8s -- upgrade`.
- **Wrong/old chart versions** → check `ARTIFACTS_VERSION` resolution (`make k8s -- … -a <v>` →
  `releases/<v>-artifacts.yaml`); `make k8s -- template` to inspect rendered output.
- **Accidental whole-stack op** → `install`/`upgrade`/`delete` without `-l` targets everything; the
  auto-`diff`/confirm (or type-to-confirm on delete) is your stop — read it.

When unsure, prefer `-n` (dry-run) and `diff`, report what you see, and ask before mutating shared envs.
