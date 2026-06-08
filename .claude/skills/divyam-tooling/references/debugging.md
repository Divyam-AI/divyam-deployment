# Debugging a Divyam stack deployment

Problem → diagnosis → fix playbook for when `make k8s -- install/upgrade` (helmfile sync/apply) fails
or releases don't come healthy. Pairs with `kubectl.md` (command reference) and `helm-helmfile.md`.
Get kubeconfig first: `make k8s -- kubeconfig`. On a **MicroK8s sandbox**, the binaries may need
`sudo microk8s kubectl` / `sudo microk8s helm` if `kubectl`/`helm` hit `Insufficient permissions`.

## How the install behaves (read this first)
- **Ordering via `needs`.** `k8s/helmfile.yaml.gotmpl` defines a `needs` map (e.g. `superset` needs
  `superset-postgres`; `*-postgres`/`mysql`/`clickhouse` need `external-secrets-operator`). Helmfile
  installs in dependency order; **a release that fails aborts every release after it** in the order —
  so the first failure is the real one, later "missing" releases are just downstream of it.
- **`--atomic --timeout 1200s`.** If a release's pods don't become Ready within the timeout, helm
  **rolls it back and uninstalls it** (`context deadline exceeded`). The pod is then gone, so inspect
  via the SecretStore/events/PVC, not the (deleted) pod.
- **Idempotent + resumable.** Re-running `make k8s -- install` (sync) or `upgrade` (apply) is safe:
  already-`deployed` releases are no-ops and it retries from the failure. A transient pull/timeout
  often clears on the second run (image now cached). Target one release to iterate fast:
  `make k8s -- diff -l <chart>` then `make k8s -- upgrade -l <chart>`.

## First triage (always)
```bash
make k8s -- status                       # helm ls -A — which releases are deployed vs failed
kubectl get pods -A | grep -vE 'Running|Completed'   # anything unhealthy, by namespace
```
Namespaces are `<chart>-<env>-ns` (e.g. `superset-dev-ns`). For one release:
```bash
kubectl get pods,pvc,svc -n <chart>-<env>-ns
kubectl get events -n <chart>-<env>-ns --sort-by=.lastTimestamp | tail -20
kubectl describe pod <pod> -n <chart>-<env>-ns        # events at the bottom say why
kubectl logs <pod> -n <chart>-<env>-ns [-c <container>] [--previous]
```

## Failure modes

### Release times out / rolled back (`context deadline exceeded`)
The pod didn't reach Ready in `--timeout`. Walk the dependencies a pod waits on:
- **Secret missing?** → see *ExternalSecret* below (most common cause of a DB pod never starting).
- **PVC pending?** `kubectl get pvc -A | grep -v Bound` — no/incompatible StorageClass.
- **Image pull?** `kubectl describe pod …` → `ImagePullBackOff` → registry pull-secret (GAR /
  `TF_VAR_divyam_artifactory_docker_auth`). See `kubectl.md`.
- **Scheduling/resources?** `kubectl describe node | grep -A6 'Allocated resources'` and the pod's
  `nodeSelector`/requests in `resources.yaml`.
To inspect a release that keeps getting rolled back, retry with atomic off / a longer wait so the
failed pod survives for `describe`/`logs`: `make k8s -- upgrade -l <chart> -- --no-atomic --timeout 300s`
(args after a second `--` pass straight to helmfile/helm; confirm with `./scripts/k8s.sh help`).

### ExternalSecret / secrets not resolving
The secret chain: `provider.yaml` `secrets:` → **external-secrets-operator** → `SecretStore` →
`ExternalSecret` → the k8s `Secret` a chart mounts. Charts only render an ExternalSecret when
`secrets.provider` is a **cloud SM or `OPENBAO`** (see `charts/*/templates/external-secret.yaml`,
gated on `$isCloud`/`$isOpenbao`) — there is no plain-k8s secret mode.
```bash
kubectl get secretstore,externalsecret -A
kubectl describe secretstore <name> -n <ns>     # InvalidProviderConfig / auth / "no such host" → backend unreachable
kubectl describe externalsecret <name> -n <ns>  # SecretSyncedError → store not ready
```
- `no such host <backend>.svc` → the secrets backend (OpenBao / cloud SM) isn't deployed/reachable in
  this env. The dependent DB pod then never gets its Secret and times out. Fix = stand up + seed the
  backend, or point `secrets.provider`/addr in `provider.yaml` at a reachable one.
- Cloud SM auth errors → the operator's IRSA/Workload-Identity binding (Phase-1 `2-app` IAM).

### `provider.yaml` / `resources.yaml` not found (helmfile template parse error)
`open provider.yaml: no such file or directory` at `helmfile.yaml.gotmpl` parse time means
`HELMFILE_VALUES_DIR` didn't resolve to the dir holding `provider.yaml`/`resources.yaml`. helmfile
resolves `readFile` relative to the **helmfile's own dir** (`k8s/`), so the values dir must be passed
as a path that resolves regardless of CWD. Use `-d <dir>` (absolute is fine); confirm the two files
exist there. (`scripts/k8s.sh` exports the absolute `HELMFILE_VALUES_DIR` for this reason.)

### `no such values dir: <dir>`
`scripts/k8s.sh` couldn't find `-d`'s dir. It accepts absolute or repo-relative paths; the dir must
contain `provider.yaml` + `resources.yaml` (copy from `k8s/helm-values/sample-config.yaml`).

### Chart/repo fetch fails (`404` / `connection reset by peer`)
Transient registry/GitHub-Pages flakiness → just re-run (idempotent). A persistent `404` means a
chart repo URL moved — check the `repositories:` block at the top of `helmfile.yaml.gotmpl`.

## Don't mutate to "fix"
The Helmfile owns manifests. Prefer `make k8s -- diff`/`upgrade -l <chart>` over hand
`kubectl apply/delete` (those `ask` by policy). Patch directly only for break-glass inspection.
