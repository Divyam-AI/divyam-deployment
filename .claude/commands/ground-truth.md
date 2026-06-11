---
description: Read authoritative cloud state via REST (no az/gcloud needed) — inventory the RG/project, count clusters, inspect a subnet, check OIDC issuer. Read-only.
argument-hint: "[clusters|subnet <name>|inventory|issuer]"
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(kubectl get:*), Read, Skill
---
You answer "what actually exists in the cloud right now?" using the SP/ADC creds the IaC already
has — for when `az`/`gcloud` isn't installed, or to verify a human handoff / diagnose a conflict
before importing or deleting anything. Adopt `divyam-platform-engineer`. **Read-only — only GET
requests**; never mutate via REST without an explicit, reviewed go-ahead. Optional focus:
**$ARGUMENTS**. Follow the recipes in `divyam-tooling/references/ground-truth-rest.md`.

1. **Get a token** from `iac/values/secrets.env` creds (Azure SP client-credentials → ARM; GCP
   `gcloud auth print-access-token` or metadata). Confirm you got one; never print it.
2. **Answer the ask** (default = inventory):
   - `inventory` — all resources in the deployment RG/project (`type  name`, sorted).
   - `clusters` — managed clusters + provisioning state (catch duplicates).
   - `subnet <name>` — delegations + attached ipConfigurations (catch a VM NIC squatting the app-gw
     subnet → the App-GW collision).
   - `issuer` — cluster OIDC issuer vs a UAMI's federated-cred issuer (catch the cluster-recreate
     workload-identity drift).
3. **Report** the facts plainly and the implication (e.g. "1 cluster, no duplicate"; "app-gw subnet
   has a non-gateway NIC → app_gw apply will fail"; "federated issuer ≠ cluster issuer → rebind
   needed"). Point to the matching recovery step (`/import-existing`, `/verify-workload-identity`,
   `/apply-nap-configs`). Make no changes.
