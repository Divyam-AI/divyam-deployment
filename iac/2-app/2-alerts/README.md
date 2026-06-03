# 2-alerts

Cloud-agnostic alert rules in `common/rules/`; Terragrunt units translate them to GCP, Azure, or Datadog.

Deploy flows and custom-K8s notes: [`iac/README.md`](../README.md#monitoring-and-observability). Rule schema: [`common/rules/README.md`](common/rules/README.md).

## Layout

```
2-alerts/
├── common/rules/           # Neutral JSON (single source of truth)
├── azure/{datadog,prometheus}
├── gcp/alerts/{datadog,prometheus}
├── gcp/notification_channels/
└── datadog/                # Standalone; use TG_STANDALONE_DATADOG_ALERTS=1 only
```

## Which unit runs

| `alerts.enabled` | `datadog.enabled` | Active unit |
|------------------|-------------------|-------------|
| false | * | skipped |
| true | false | `*/prometheus` |
| true | true | `*/datadog` |

On custom K8s (`k8s.create = false`), set `datadog.custom_cluster_name` (or `k8s.name`) to match `{{cluster_name}}` in rules.

## Config (`values/defaults.hcl`)

Set `NOTIFICATION_WEBHOOK_URLS` (comma-separated) for paging webhooks — do not commit URLs to git.

Datadog monitors also need `TF_VAR_datadog_api_key` and `TF_VAR_datadog_app_key`.

## Run

```bash
export VALUES_FILE=values/<your-env>.hcl
export CLOUD_PROVIDER=gcp   # or azure

cd iac/2-app
terragrunt run plan --all \
  --filter "./**/${CLOUD_PROVIDER}" \
  --filter "./**/${CLOUD_PROVIDER}/**"
```

Azure/GCP filters must include `**` so nested paths like `azure/datadog` match.

## Adding a rule

1. Edit `common/rules/<group>.json`.
2. Add `datadog.query` when using Datadog.
3. Re-plan the destination for your profile.
