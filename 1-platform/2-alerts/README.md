# 2-alerts

Alerts and notification channels for Azure and GCP, driven by `values/defaults.hcl` (`alerts` and `alerts.notification_channels`).

## Layout

- **common/** – Shared alert rule definitions only (no cloud-specific code).
  - **alerts/** – Azure Prometheus format (JSON). Used by Azure.
  - **rules/** – GCP format (JSON with `{{project_id}}` / `{{cluster_id}}`). Used by GCP.

- **azure/** – Azure Monitor action group + Prometheus rule groups. Reads rules from `common/alerts/`. Tags follow the same pattern as 1-k8s (common_tags, tag_globals, tag_context).

- **gcp/** – All GCP-specific alert code lives here.
  - **notification_channels/** – Terraform for GCP notification channels (email, webhook, Google Chat). Apply first.
  - **alerts/** – Terragrunt that runs the GCP alerts module (repo `gcp/alerts`), depends on notification_channels, loads rules from `common/rules/`.

## Config (values/defaults.hcl)

- `alerts.create`, `alerts.enabled`, `alerts.exclude_list`
- `alerts.notification_channels`: `pager_enabled`, `pager_webhook_url`, `gchat_enabled`, `gchat_space_id`, `email_enabled`, `email_alert_email`, `slack_enabled`, `slack_webhook_url`
- Notification URLs/IDs are read from env in defaults.hcl: `NOTIFICATION_PAGER_WEBHOOK_URL`, `NOTIFICATION_GCHAT_SPACE_ID`, `NOTIFICATION_EMAIL_ALERT_EMAIL`, `NOTIFICATION_SLACK_WEBHOOK_URL`

## Run

- **Azure:** From repo root, `CLOUD_PROVIDER=azure terragrunt run-all plan --terragrunt-working-dir 2-alerts/azure`
- **GCP:** Apply notification_channels then alerts:  
  `CLOUD_PROVIDER=gcp terragrunt run-all plan --terragrunt-working-dir 2-alerts/gcp`
