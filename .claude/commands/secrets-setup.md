---
description: Generate and complete iac/values/secrets.env — assign the real FILL values (cloud creds, GAR docker-auth, webhooks) as action items to the team and verify before proceeding.
argument-hint: "[gcp|azure] [env]"
allowed-tools: Bash(make:*), Bash(jq:*), Bash(ls:*), Read, Skill
---
You set up the Phase-1 secrets/config file the IaC reads. Adopt `divyam-platform-engineer`. Optional
args (cloud, env): **$ARGUMENTS**. **Never print, echo, or paste secret values** — only confirm
presence/shape.

1. **Generate if missing.** If `iac/values/secrets.env` doesn't exist, `make iac -- secrets`
   (wraps `gen-tf-env.sh`). Randomizable secrets are pre-filled; real ones are placeholders.
2. **Identify the real `FILL` values that must be provided by a human** (read the file's `FILL`
   markers — do not display their values):
   - **Cloud creds** — Azure `ARM_CLIENT_ID/_SECRET/_SUBSCRIPTION_ID/_TENANT_ID`; GCP
     `GOOGLE_APPLICATION_CREDENTIALS` (or ADC).
   - **Registry (Azure only)** — `TF_VAR_divyam_artifactory_docker_auth` = a **path** to the Divyam
     GAR dockerconfigjson file. **GCP does not need this** (GAR via SA/metadata) — leave blank.
   - **Webhooks/vendor** — `NOTIFICATION_WEBHOOK_URLS` (Zenduty), `TF_VAR_datadog_*`,
     `TF_VAR_grafana_api_token`, Divyam deployment id/key (if registering with Divyam).
3. **Assign action items + pause.** Tell the team exactly which values to fill and how (edit the file,
   or `export` then re-run with `--force`). For the Azure docker-auth, the file must be a complete,
   valid dockerconfigjson — warn that terminal pastes often truncate at 4096 bytes.
4. **Verify on resume (don't trust, check):**
   - Cloud auth: `make iac -- creds` passes.
   - Azure docker-auth: the path exists and `jq empty <path>` succeeds (valid JSON, ends in `}}}`,
     comfortably > 4 KB) — never cat it.
   - Config separation: `CLOUD_PROVIDER`/`ENV`/`VALUES_FILE` should come from `.iac.conf` / CLI /
     `iac.env`, **not** be a stale value baked into secrets.env (that silently forks state — see
     known-gotchas §3). If `VALUES_FILE` here points at a non-existent file, flag it.
5. Report what's still missing; only declare ready when creds validate and required reals are present.
