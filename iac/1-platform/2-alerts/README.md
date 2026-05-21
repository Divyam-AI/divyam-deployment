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

| `alerts.enabled` | `datadog.enabled` | Azure / GCP alerts | Datadog alerts |
|------------------|-------------------|--------------------|----------------|
| false            | *                 | skipped            | skipped        |
| true             | false             | applied            | skipped        |
| true             | true              | skipped            | applied        |

The cloud-native (Azure / GCP) and Datadog paths are mutually exclusive.

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

```bash
# Azure (datadog.enabled = false):
CLOUD_PROVIDER=azure terragrunt run-all plan --terragrunt-working-dir 2-alerts/azure

# GCP (notification_channels first, then alerts; both gated by datadog.enabled = false):
CLOUD_PROVIDER=gcp terragrunt run-all plan --terragrunt-working-dir 2-alerts/gcp

# Datadog (datadog.enabled = true, alerts.enabled = true):
terragrunt plan --terragrunt-working-dir 2-alerts/datadog
```

## Adding a new alert

1. Edit (or add) a group file under `common/rules/<group>.json`.
2. Append a new entry to `rules[]` following the schema in `common/rules/README.md`.
3. Provide the `datadog.query` if Datadog should monitor it.
4. Re-plan against the active destination.
