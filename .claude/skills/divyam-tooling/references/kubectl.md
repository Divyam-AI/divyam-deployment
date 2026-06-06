# kubectl (verification & debugging)

You mostly use `kubectl` to **verify** Phase 1/2 results and debug, not to mutate (the Helmfile owns
manifests). Get kubeconfig first with `make k8s -- kubeconfig`.

## Allow-listed (run freely; see `.claude/settings.json`)
- `kubectl get …`   — `kubectl get ns`, `kubectl get pods -A`, `kubectl get pods -n <chart>-<env>-ns`,
  `kubectl get svc,ingress -A`, `kubectl get nodes`.
- `kubectl describe …` — `kubectl describe pod <pod> -n <ns>` (events at the bottom explain pending/crashloop).
- `kubectl logs …` — `kubectl logs <pod> -n <ns> [-c <container>] [--previous] [-f]`.
- `kubectl rollout status …` — `kubectl rollout status deploy/<name> -n <ns>`.
- `kubectl config …` — `kubectl config current-context`, `kubectl config get-contexts`.

## Prompts first (`ask` in settings) — use sparingly, with intent
- `kubectl apply …`, `kubectl delete …` — the stack is managed by Helmfile; prefer `make k8s -- upgrade`
  / `make k8s -- delete` over hand `kubectl apply/delete`. Only patch directly for break-glass debugging.

## Verification recipes
- Cluster reachable: `kubectl get ns` (after `make k8s -- kubeconfig`).
- Stack health: `kubectl get pods -A | grep -vE 'Running|Completed'` (anything left is unhealthy);
  pair with `make k8s -- status` (`helm ls -A`).
- A release: `kubectl get pods -n <chart>-<env>-ns`; `kubectl rollout status deploy/<chart> -n <chart>-<env>-ns`.
- Image pull issues: `kubectl describe pod …` → look for `ImagePullBackOff` (registry pull-secret /
  `TF_VAR_divyam_artifactory_docker_auth`), then `kubectl get events -n <ns> --sort-by=.lastTimestamp`.
- Pending pods: `kubectl describe pod …` → scheduling/`nodeSelector`/resources (see `resources.yaml`).

## TUI / dashboard
- `k9s` — cluster-wide terminal UI (pods/logs/exec/port-forward). Installed by `make prereqs`.
- `make k8s -- status --tui` (`helm tui`) — release-focused terminal UI.
- `make k8s -- status --dashboard` (`helm dashboard`) — web UI at localhost:8080.
