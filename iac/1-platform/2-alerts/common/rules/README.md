# Alert rules (neutral format)

One JSON file per logical group. Each file is rendered into Azure / GCP / Datadog
by the respective `2-alerts/<destination>/` module.

## Schema

```jsonc
{
  "name": "kubernetes",                    // group name (used as resource name)
  "description": "...",                    // optional
  "interval": "1m",                        // evaluation interval (Go-duration shorthand: s|m|h)
  "rules": [
    {
      "alert": "deployment-replica-mismatch",  // unique within group; lowercase + hyphens
      "expr": "PromQL expression",             // used by Azure + GCP managed Prometheus
      "for": "2m",                             // pending duration before firing
      "severity": "CRITICAL",                  // CRITICAL | WARNING | INFO
      "auto_resolve": "30m",                   // optional; null = no auto-close
      "enabled": true,                         // optional; default true
      "labels": {
        "rule_group": "Kubernetes",            // free-form, attached to the alert
        "alert_rule": "AlwaysOn"
      },
      "annotations": {
        "summary": "...",                      // short title
        "description": "..."                   // long description
      },

      "datadog": {                             // optional. required only when datadog.enabled.
        "query": "min(last_15m):metric{kube_cluster_name:{{cluster_name}}} ... < 0.8",  // {{cluster_name}}; comparison must match thresholds.critical
        "thresholds": {                        // required for Datadog; warning/critical/recovery
          "critical": "0.8",
          "warning": "0.9",
          "critical_recovery": "0.85",
          "warning_recovery": "0.95"
        },
        "notify": true,                        // optional; true pages WARNING rules (e.g. pvc-usage-high)
        "message": "...",
        "type": "metric alert"
      }
    }
  ]
}
```

## Duration format

Plain Go-duration shorthand only: `30s`, `2m`, `1h`. Modules convert:

- Azure → ISO-8601 (`PT30S`, `PT2M`, `PT1H`)
- GCP → seconds string (`30s`, `120s`, `3600s`)
- Datadog → window seconds for `last_<N>` aggregator

## Severity mapping

| Neutral    | Azure (label) | GCP enum  | Datadog priority | Webhooks notified? |
|------------|---------------|-----------|------------------|---------------------|
| `CRITICAL` | `CRITICAL`    | `CRITICAL`| 1                | yes                 |
| `WARNING`  | `WARNING`     | `WARNING` | 3                | no                  |
| `INFO`     | `INFO`        | `INFO`    | 5                | no                  |

Only `CRITICAL` rules notify the configured `alerts.webhook_urls`. Lower-severity
rules still fire (rule group / alert policy / monitor are created) but no
external notification is dispatched.

## Datadog block

Datadog monitors don't speak PromQL natively, so each rule must provide a
`datadog.query` if it should produce a Datadog monitor. Rules without a
`datadog` block are silently skipped on Datadog (logged at plan time).

The Datadog metric names typically come from the Datadog Kubernetes integration
(prefix `kubernetes_state.*` or `kubernetes.io.*`), not from the upstream
kube-state-metrics names used by Azure/GCP managed Prometheus.

**Query vs `thresholds`:** Datadog validates that the comparison value in `query`
(e.g. `< 0.8`, `> 80`) matches `thresholds.critical`. Put warning/recovery only in
`thresholds`, not in the query string. Do not use `OR` inside tag filters — sum
separate metric expressions instead (see `pvc-unbound-state`).

**Replica ratio monitors** (`deployment-replica-mismatch`, `statefulset-replica-mismatch`):
warn at `< 0.9`, critical at `< 0.8`, with recovery at `0.85` / `0.95` (~5–10% above
the alert boundary) to reduce flapping.

**Count monitors** (crashloop, failed pods, unbound PVC): use query `> 0` only — omit
`thresholds`. Datadog rejects `critical_recovery` equal to `critical` on `>` comparisons;
recovery happens automatically when the series drops to zero.

## Datadog module defaults (`alerts.*` in values)

| Setting | Default | Purpose |
|---------|---------|---------|
| `notify_no_data` | `true` | Page when metrics stop flowing |
| `no_data_timeframe` | `15` | Minutes without data before no-data alert |
| `renotify_interval` | `30` | Re-page CRITICAL monitors every 30 minutes while still firing |

Override in `VALUES_FILE` under `alerts`. `renotify_interval` applies only to
`severity: CRITICAL` monitors (not WARNING rules with `datadog.notify`).
