---
description: Diagnose a failed/unhealthy Divyam stack deployment — find the first failing release and why. Read-only.
argument-hint: "[release or namespace, optional]"
allowed-tools: Bash(make:*), Bash(helm ls:*), Bash(kubectl get:*), Bash(kubectl describe:*), Bash(kubectl logs:*), Skill
---
Use `divyam-tooling` (`references/debugging.md`). Read-only diagnosis via the Makefile entrypoint. Optional
focus (from args): **$ARGUMENTS**. Ensure kubeconfig first (`make k8s -- kubeconfig`).

1. **Triage:** `make k8s -- status` (`helm ls -A`) — note which releases are `deployed` vs `failed`.
   Then `kubectl get pods -A | grep -vE 'Running|Completed'`. Remember: helmfile installs in `needs`
   order and **a failed release aborts the ones after it** — so identify the *first* failure; later
   "missing" releases are usually just downstream.
2. **Drill into the first failure** (or $ARGUMENTS if given). Namespace is `<chart>-<env>-ns`:
   `kubectl get pods,pvc,svc -n <ns>`, `kubectl get events -n <ns> --sort-by=.lastTimestamp | tail -20`,
   `kubectl describe pod <pod> -n <ns>`, `kubectl logs <pod> -n <ns> [--previous]`.
3. **Match the failure mode** (see `references/debugging.md`): `context deadline exceeded` (atomic
   rollback → check Secret/PVC/image/scheduling); ExternalSecret/SecretStore not resolving (secrets
   backend unreachable); `provider.yaml`/values-dir not found; transient chart-fetch errors.
4. **Report** the first failing release, the root cause with the evidence line, and the suggested next
   step (e.g. re-run `make k8s -- upgrade -l <chart>`, fix the secrets backend, fix `-d`/values). Don't
   mutate anything — propose `make k8s -- diff/upgrade -l <chart>` rather than hand `kubectl apply/delete`.
