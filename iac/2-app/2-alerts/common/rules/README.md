# Alert rules (neutral format)

One JSON file per logical group. Files are loaded by the shared **`common/render`** module, which
renders backend-specific queries and rule objects; the per-backend units (`gcp/alerts`, `azure`,
`datadog`) then map those onto resources. `metric_map.json` in this folder is the central metric
catalog (not a rule group).

The schema is a **superset** — it exposes an exhaustive set of alert configuration. Each backend
honors what it can and **gracefully ignores the rest**; see the capability matrix below for what is
honored where.

## Query authoring is hybrid

A rule defines its query in **one** of two ways:

1. **Structured `query` IR** (preferred) — the renderer builds *both* the PromQL `expr` (GCP + Azure)
   and the Datadog query from structured fields, resolving metric names through `metric_map.json`.
   Thresholds, look-back window, cluster, and env are injected at render time — they never appear in
   a hand-written string.
2. **Template** (`expr` + `datadog.query`) — an escape hatch for shapes the IR can't express (e.g.
   summing differently-filtered series, anomaly/forecast/composite monitors). You author the query
   string per backend with placeholders; the renderer substitutes them.

## Schema

```jsonc
{
  "name": "kubernetes",          // group name -> Azure rule-group resource name
  "description": "...",          // optional
  "interval": "1m",              // evaluation interval (Go-duration shorthand: s|m|h)
  "enabled": true,               // optional; group-level toggle (default true)
  "labels": {                    // optional; merged into EVERY rule's labels
    "rule_group": "Kubernetes"
  },
  "rules": [
    {
      "alert": "deployment-replica-mismatch", // unique within group; lowercase + hyphens
      "for": "2m",                            // pending duration before firing
      "window": "15m",                        // look-back (Datadog last_<window>); separate from `for`
      "severity": "CRITICAL",                 // CRITICAL | WARNING | INFO (severity of the critical tier)
      "auto_resolve": "30m",                  // optional; null = no auto-close
      "enabled": true,                        // optional; default true

      // ---- (1) Structured query IR ----------------------------------------
      "query": {
        "terms":       [ { "metric": "replicas_available", "filters": {} } ], // 1+ terms (generic names)
        "denominator": [ { "metric": "replicas_desired" } ],                  // optional => ratio (num/den)
        "combine":     "sum",                  // how multiple terms combine (sum); min/max => use a template
        "comparison":  "<",                    // < > <= >= ==   (shared by both backends)
        "scale":       1,                      // optional multiplier (e.g. 100 to express a percentage)
        "aggregation": "avg",                  // Datadog space aggregator: avg|sum|min|max
        "group_by":    ["kube_namespace", "kube_deployment"], // Datadog `by {...}`
        "rollup":      "min"                   // Datadog time rollup over the window: min|max|avg|sum
      },

      // ---- (2) OR template (omit `query`) ---------------------------------
      // "expr":    "(metric{phase!='Bound'}) > {{threshold}}",
      // "datadog": { "query": "max(last_{{window}}):sum:...{kube_cluster_name:{{cluster_name}}} > {{threshold}}" },

      "thresholds": {                          // neutral; drives multi-tier (see below)
        "critical": "0.8",
        "warning": "0.9",
        "critical_recovery": "0.85",           // Datadog only (no Prometheus hysteresis)
        "warning_recovery": "0.95"             // Datadog only
      },

      "notification": {                        // optional; see capability matrix
        "notify": true,                        // force paging even for non-CRITICAL (all backends)
        "priority": 1,                         // Datadog only; overrides severity-derived priority
        "renotify_interval": "30m",            // Datadog (re-page); GCP via rate-limit
        "renotify_statuses": ["alert", "warn"],// Datadog only
        "notify_no_data": true,                // Datadog only
        "no_data_timeframe": "15m"             // Datadog only
      },

      "labels": { "alert_rule": "AlwaysOn" },  // merged over group labels
      "annotations": {
        "summary": "...",                      // short title
        "description": "...",                  // long description
        "runbook_url": "https://...",          // optional; rendered into docs/annotation/message
        "dashboard_url": "https://..."         // optional
      },

      "datadog": {                             // optional per-backend overrides
        "type": "metric alert",                // monitor type (default "metric alert")
        "message": "...",                      // overrides annotations.description for the monitor
        "thresholds": { "critical": "80", "warning": "60", ... }, // wins over neutral thresholds on Datadog
        "query": "..."                         // only for template rules
      },
      "gcp":   { "notification_channels": ["..."] }, // optional per-rule channel override
      "azure": { "expr": "..." }                     // optional PromQL override
    }
  ]
}
```

## Placeholders (template rules)

Substituted by the render module: `{{cluster_name}}`, `{{env}}`, `{{window}}`, `{{threshold}}`
(replaced with the critical value — or `datadog.thresholds.critical` on Datadog). Author the
comparison operator and rollup literally in template mode.

`{{env}}` exists for env-suffixed namespaces. Namespaces follow `<group>-<env>-ns` (e.g.
`eval-prod-ns`, `otel-collector-dev-ns`), so scope a rule to one with `kube_namespace:eval-{{env}}-ns`.

## Metric catalog (`metric_map.json`)

Maps a generic metric name to its per-backend identifier:

```jsonc
"replicas_available": { "prometheus": "kube_deployment_status_replicas_available",
                        "datadog":    "kubernetes_state.deployment.replicas_available" }
```

The renderer resolves a `query.terms[].metric` here. **If a generic name is absent, it is used
as-is** for both backends. Datadog metric names + filter values are **normalized** (lowercase,
`-` → `_`) at emit time, so list Datadog names in canonical form and write filter values naturally
(e.g. `"reason": "CrashLoopBackOff"` → `reason:crashloopbackoff`).

## Multi-tier thresholds → two Prometheus rules

PromQL backends evaluate one threshold per rule; Datadog supports native warning + critical tiers in
one monitor. So when a rule declares **both** `thresholds.warning` and `thresholds.critical`, the
renderer emits **two** Prometheus rules:

| Tier | Alert name | Threshold | Severity |
|------|-----------|-----------|----------|
| critical | `<alert>` (unchanged) | `thresholds.critical` | the rule's `severity` |
| warning  | `<alert>-warning`     | `thresholds.warning`  | `WARNING` (non-paging) |

Datadog stays a **single** monitor (base name) with native `monitor_thresholds`. So the base alert
name `<alert>` exists on every backend — the closed-loop sims (`test/alert-sim/*.yaml`,
`match_field: alert`) keep matching. Rules with only `thresholds.critical` (e.g. count `> 0`) render
as a single rule and emit no `monitor_thresholds`. `*_recovery` thresholds are Datadog-only.

## Duration format

Plain Go-duration shorthand only: `30s`, `2m`, `1h`. Converted per backend:

- Azure → ISO-8601 (`PT30S`, `PT2M`, `PT1H`)
- GCP → seconds string (`30s`, `120s`, `3600s`)
- Datadog → `last_<window>` window; `notification.*` minutes (renotify / no-data)

## Severity mapping

| Neutral    | Azure (label) | GCP enum  | Datadog priority | Pages webhooks? |
|------------|---------------|-----------|------------------|------------------|
| `CRITICAL` | `CRITICAL`    | `CRITICAL`| 1                | yes              |
| `WARNING`  | `WARNING`     | `WARNING` | 3                | only if `notification.notify` |
| `INFO`     | `INFO`        | `INFO`    | 5                | only if `notification.notify` |

Only `CRITICAL` rules (or any rule with `notification.notify: true`) notify the configured webhooks.
Lower-severity rules still fire (resource is created) but don't page otherwise.

## Capability matrix — what each backend honors

| Field | GCP Cloud Monitoring | Azure Managed Prom | Datadog |
|---|---|---|---|
| `query` IR / `expr` / `for` / `interval` | ✅ (PromQL) | ✅ (PromQL) | ✅ (rendered DD query) |
| `window` (look-back) | ⚠️ only if a range query | ⚠️ only if a range query | ✅ `last_<window>` |
| `query.aggregation` / `group_by` / `rollup` | ❌ (per-series) | ❌ (per-series) | ✅ |
| `severity` / `enabled` / `auto_resolve` | ✅ | ✅ | ✅ / ⚠️ rule-only / auto-on-recovery |
| `labels` (+ group labels) / `annotations` | ✅ | ✅ | ✅ (tags / message) |
| `annotations.runbook_url` / `dashboard_url` | ✅ documentation | ✅ annotation | ✅ message |
| `thresholds` multi-tier | ⚠️ → 2 rules | ⚠️ → 2 rules | ✅ native |
| `thresholds.*_recovery` | ❌ | ❌ | ✅ |
| `notification.notify` (page override) | ✅ attach channel | ✅ attach action group | ✅ @-handle |
| `notification.priority` | ❌ | ❌ | ✅ |
| `notification.renotify_interval` | ⚠️ `notification_rate_limit` | ❌ | ✅ |
| `notification.renotify_statuses` | ❌ | ❌ | ✅ |
| `notification.notify_no_data` / `no_data_timeframe` | ❌ | ❌ | ✅ |
| `{{env}}` namespace templating | ✅ | ✅ | ✅ |
| `datadog.*` / `gcp.*` / `azure.*` overrides | gcp only | azure only | datadog only |

✅ honored · ⚠️ partial / conditional · ❌ ignored (silently)

## Datadog module defaults (`alerts.*` in values)

Per-rule `notification.*` overrides these module-level defaults:

| Setting | Default | Purpose |
|---------|---------|---------|
| `notify_no_data` | `true` | Page when metrics stop flowing |
| `no_data_timeframe` | `15` (min) | Minutes without data before a no-data alert |
| `renotify_interval` | `30` (min) | Re-page CRITICAL/paging monitors while still firing |

## Adding a rule

1. Add the metric(s) to `metric_map.json` if not present (or rely on as-is fallback).
2. Add the rule to `common/rules/<group>.json` — prefer the structured `query` IR; use a template
   only when the shape diverges per backend.
3. Add a simulation scenario in `test/alert-sim/<group>.yaml`.
4. Re-plan the destination for your profile and prove it with `/alert-loop`.
