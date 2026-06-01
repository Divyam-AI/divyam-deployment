# 2-dashboards

Per-destination dashboards, uploaded as-is. Deploy with alerts: [`iac/README.md`](../README.md#monitoring-and-observability).

> Dashboards are authored offline in each destination's native JSON format. This
> module just uploads them. There is no transpilation step — each cloud has its
> own dashboard folder.

## Layout

```
2-dashboards/
├── azure/
│   ├── dashboards/*.json     Grafana dashboard JSON  (Azure Managed Grafana)
│   └── main.tf etc.
├── gcp/
│   ├── dashboards/*.json     Cloud Monitoring native JSON
│   └── main.tf etc.
└── datadog/
    ├── dashboards/*.json     Native Datadog dashboard JSON (raw export)
    └── main.tf etc.
```

## Selection logic

Driven by `datadog.enabled` from `values/defaults.hcl`:

| `datadog.enabled` | Azure / GCP dashboards | Datadog dashboards |
|-------------------|------------------------|--------------------|
| false             | applied                | skipped            |
| true              | skipped                | applied            |

The cloud-native (Azure / GCP) and Datadog paths are mutually exclusive.

## Authoring

### Datadog
Export dashboards from the Datadog UI ("Configure" → "Export Dashboard JSON") or via
`scripts/datadog_dashboard_bulk.sh --mode download`. Place the JSON files into
`datadog/dashboards/`. Filenames are arbitrary; the dashboard's own `id` / `title`
are used by the Datadog API.

### GCP
Export from Cloud Monitoring ("..." menu → "Edit dashboard JSON" → copy). Place into
`gcp/dashboards/`. Filename has no semantic meaning; the JSON's `displayName` is what
shows in the UI. See [Cloud Monitoring Dashboards REST schema](https://cloud.google.com/monitoring/api/ref_v3/rest/v1/projects.dashboards).

### Azure
Standard Grafana dashboard exports (from any Grafana UI: "Share" → "Export" → "Save
to file"). Place into `azure/dashboards/`. Will be applied against the Azure Managed
Grafana instance created in `1-platform/2-monitoring/native/azure` (or set `monitoring.native.grafana_endpoint` for BYO Grafana).

## Required env vars

### Datadog (when `datadog.enabled = true`)

```bash
export TF_VAR_datadog_api_key=...
export TF_VAR_datadog_app_key=...
```

### Azure (when `datadog.enabled = false` and `CLOUD_PROVIDER=azure`)

```bash
# Create a Grafana service account + token in the Azure Managed Grafana UI:
#   Administration -> Service accounts -> New service account ("Admin" role)
#   -> Add service account token -> copy.
export TF_VAR_grafana_api_token=...
```

## Run

```bash
# Azure (when datadog.enabled = false):
CLOUD_PROVIDER=azure terragrunt plan --terragrunt-working-dir 2-app/2-dashboards/azure

# GCP (when datadog.enabled = false):
CLOUD_PROVIDER=gcp terragrunt plan --terragrunt-working-dir 2-app/2-dashboards/gcp

# Datadog (datadog.enabled = true):
terragrunt plan --terragrunt-working-dir 2-app/2-dashboards/datadog
```
