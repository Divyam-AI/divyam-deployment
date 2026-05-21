# 2-alerts

Cloud-agnostic alerts, driven by `values/defaults.hcl` (`alerts`, `datadog`).

> [!NOTE]
> Notification endpoints are supplied via a list of pager / Zenduty-style webhook
> URLs. Do not commit webhook URLs to git — set `NOTIFICATION_WEBHOOK_URLS` from
> your secret manager or CI.

> [!NOTE]
> Notification endpoints are supplied via environment variables referenced from `defaults.hcl` — see **Config** below. Do not commit webhook URLs or tokens to git; use your secret manager or CI-injected variables.

## Layout

```
2-alerts/
├── common/
│   └── rules/                  Neutral alert schema (single source of truth)
│       ├── README.md           Schema doc
│       └── k8s.json            Default Kubernetes alerts
├── azure/                      Azure Monitor action group + Prometheus rule groups
├── gcp/
│   ├── alerts/                 google_monitoring_alert_policy (Prometheus query language)
│   └── notification_channels/  One webhook_tokenauth channel per URL (apply first)
└── datadog/                    datadog_monitor per rule + datadog_webhook per URL
                                (when datadog.enabled = true)
```

The same `common/rules/*.json` files are read by all three destination modules.
Each module translates the neutral schema into its native form. See
`common/rules/README.md` for the schema, duration handling, severity mapping, and
the optional `datadog` block (Datadog needs its own query DSL — PromQL is not portable).

## Selection logic

| `alerts.enabled` | `datadog.enabled` | `2-alerts/azure` or `gcp/alerts` unit |
|------------------|-------------------|----------------------------------------|
| false            | *                 | skipped                                |
| true             | false             | Azure / GCP Prometheus alerts          |
| true             | true              | `2-alerts/azure/datadog` or `gcp/alerts/datadog` runs |

Use `terragrunt run-all --filter "**/azure"` (or `gcp`). Each cloud has two terragrunt
children under the alerts path — only one runs at a time:

```
2-alerts/azure/datadog/      # Datadog module (when datadog.enabled)
2-alerts/azure/prometheus/   # Azure Prom rules (when datadog.enabled = false)
2-alerts/gcp/alerts/datadog/
2-alerts/gcp/alerts/prometheus/
```

Standalone `2-alerts/datadog/` only with `TG_STANDALONE_DATADOG_ALERTS=1`.

Only `CRITICAL` rules notify the configured webhook URLs. `WARNING` / `INFO`
rules still fire but are recorded silently (no external notification).

## Config (values/defaults.hcl)

```hcl
alerts = {
  create       = false
  enabled      = true
  exclude_list = []  # alert names (rules[].alert) to skip across all destinations

  # The only notification config: one list of pager / Zenduty-style webhook URLs.
  # Set the env var as a comma-separated list:
  #   export NOTIFICATION_WEBHOOK_URLS='https://www.zenduty.com/api/...,https://hooks.opsgenie.com/...'
  webhook_urls = compact(split(",", get_env("NOTIFICATION_WEBHOOK_URLS", "")))

  # Datadog only — custom webhook JSON body (default on; see "Datadog webhook custom payload").
  webhook_custom_payload_enabled = true
  webhook_custom_payload         = null
}

datadog = {
  enabled = true
  site    = "ap1.datadoghq.com"
  env     = "prod"
  # ... other datadog fields
}
```

### Datadog webhook custom payload

| Setting | Default | Effect |
|---------|---------|--------|
| `webhook_custom_payload_enabled` | `true` | Sets `encode_as=json` and `payload` on each `datadog_webhook` |
| `webhook_custom_payload` | `null` | Built-in Zenduty template; override with a map to customize |

Built-in default:

```json
{
  "alert_id": "$ALERT_ID",
  "hostname": "$HOSTNAME",
  "date_posix": "$DATE_POSIX",
  "aggreg_key": "$AGGREG_KEY",
  "title": "$EVENT_TITLE",
  "alert_status": "$ALERT_STATUS",
  "alert_transition": "$ALERT_TRANSITION",
  "link": "$LINK",
  "event_msg": "$TEXT_ONLY_MSG"
}
```

Set `webhook_custom_payload_enabled = false` to skip custom payload (Datadog UI default).

### Per-destination behavior

- **Azure**: each URL becomes a `webhook_receiver` (with the common alert schema
  payload) on the single action group `<deployment_prefix>-alerts-action-group`.
- **GCP**: each URL becomes a `google_monitoring_notification_channel` of type
  `webhook_tokenauth` named `<env> webhook-<idx>`. All channels are attached to
  every CRITICAL alert policy.
- **Datadog**: each URL is registered as a `datadog_webhook` integration named
  `<deployment_prefix>-pager-<idx>`. Every CRITICAL `datadog_monitor` message has
  the corresponding `@webhook-<deployment_prefix>-pager-<idx>` handles appended.
  When `alerts.webhook_custom_payload_enabled = true` (default), Terraform sets
  `encode_as = json` and a Zenduty-friendly custom payload on each webhook (see below).

Datadog additionally expects these env vars before running terragrunt:

- `TF_VAR_datadog_api_key`
- `TF_VAR_datadog_app_key`

## Run

When `datadog.enabled = true`, **use the cloud path** — it sources the Datadog Terraform
module automatically (so `terragrunt run-all --filter "**/azure"` includes alerts):

```bash
export VALUES_FILE=values/<your-env>.hcl   # alerts.create=true AND alerts.enabled=true
export CLOUD_PROVIDER=azure
export TF_VAR_datadog_api_key=...
export TF_VAR_datadog_app_key=...

# Azure — use BOTH filters so nested alert units are included (2-alerts/azure/datadog
# lives under azure/ but is not matched by ./**/azure alone):
cd iac/1-platform
terragrunt run plan --all \
  --filter "./**/${CLOUD_PROVIDER}" \
  --filter "./**/${CLOUD_PROVIDER}/**"

# GCP — same pattern for 2-alerts/gcp/alerts/datadog:
terragrunt run plan --all \
  --filter "./**/gcp" \
  --filter "./**/gcp/**"
```

Standalone Datadog path (only if you are not using `2-alerts/azure` or `gcp/alerts`):

```bash
TG_STANDALONE_DATADOG_ALERTS=1 terragrunt plan --terragrunt-working-dir 2-alerts/datadog
```

### Troubleshooting: Datadog unit not in run-all queue

| Symptom | Cause | Fix |
|---------|-------|-----|
| No `2-alerts/azure` in queue | `alerts.enabled` or `alerts.create` is false in your values file | Set both true in `VALUES_FILE` |
| Plan asks for Azure `location` but Datadog downloaded | Stale `.terragrunt-cache` from switching module source in one unit | `rm -rf 2-alerts/azure/.terragrunt-cache` then re-run |
| No `2-alerts/*` in queue | Filter `./**/azure` skips nested `azure/datadog` paths | Add `--filter "./**/azure/**"` (see Run above) |
| No alert units at all | `alerts.enabled` or `alerts.create` is false in `VALUES_FILE` | Set both `true` in your values HCL |
| Datadog unit skipped | `datadog.enabled = false` in values | Set `datadog.enabled = true` for `2-alerts/azure/datadog` |
| `2-alerts/datadog` never in filter | Expected | Use `2-alerts/azure/datadog` with `**/azure/**` filter |

## Adding a new alert

1. Edit (or add) a group file under `common/rules/<group>.json`.
2. Append a new entry to `rules[]` following the schema in `common/rules/README.md`.
3. Provide the `datadog.query` if Datadog should monitor it.
4. Re-plan against the active destination.
