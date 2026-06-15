---
description: Inspect the divyam-stack observability surface — alert rules/firing state, dashboards, and the monitoring backend. Read-only.
argument-hint: "[alerts|dashboards|backend]   (omit for an overview)"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(kubectl logs:*), Bash(helm ls:*), Read, Skill
---
Use `divyam-tooling`. Read-only observability inspection (this answers "is the stack healthy by its own
alerts/SLOs", complementing `/cluster-status` = pods, and `/debug-stack` = first failing release).
Focus (from args): **$ARGUMENTS**. Get kubeconfig first if needed (`/kubeconfig`).

1. **Backend.** Identify which observability backend is active: cloud-native (GCP Cloud Monitoring /
   Azure Managed Prometheus), Datadog (`datadog.enabled`), or in-cluster kube-prometheus-stack. The
   single source of truth for alert rules is `iac/2-app/2-alerts/common/rules/*.json`.
2. **Alerts.** List the configured rule groups and flag which are CRITICAL (those notify
   `NOTIFICATION_WEBHOOK_URLS` / Zenduty). kube-prom → check Prometheus/Alertmanager pods and active
   alerts via `kubectl`. cloud-native/Datadog → point the user to the console (read-only here).
3. **Dashboards.** Enumerate `iac/2-app/2-dashboards/<backend>/` and where they're published.
4. **Backend health.** kube-prom → `kubectl get pods -n <kube-prom-ns>`; flag anything not Running.
5. **Summarize:** backend, configured-vs-firing alerts, dashboard set, and the next diagnostic
   (`/debug-stack` if something's failing). Don't mutate — to change rules, edit
   `iac/2-app/2-alerts/common/rules/*.json` (read its README) under the `terrashark` skill, then
   re-apply `make iac -- apply -l 2-app.2-alerts`.
