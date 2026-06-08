# CI/CD — forked-repo delivery (Phase 2)

For teams running ongoing deployments, the model (see `k8s/docs/cicd-overview.md` and `k8s/pipeline/`)
is a **fork of `divyam-deployment`** with PR-gated CI and post-merge CD. The CLIs map cleanly onto it.

## One-time setup
- Fork the upstream repo; the CI/CD runner lives in the **same VPC/VNet** as the cluster (network
  reach to the control plane and the auth-restricted artifact registry).
- Store cloud creds in the CI secret manager: Azure `ARM_CLIENT_ID/ARM_CLIENT_SECRET/
  ARM_SUBSCRIPTION_ID/ARM_TENANT_ID`, or GCP `GOOGLE_APPLICATION_CREDENTIALS` (SA key). Also the
  registry cred + `NOTIFICATION_WEBHOOK_URLS` as needed.
- Validate with a non-production change before pointing it at prod.

## CI — on pull request (preview only)
Entry: `k8s/pipeline/` (`ci_validate.sh`-style). Steps: checkout PR → load secrets → cloud auth +
`make k8s -- kubeconfig` → `kubectl get ns` sanity → **`make k8s -- diff`** (no apply). The diff gates the
merge; review it like a plan. Never `apply`/`sync` in CI.

## CD — on merge to main (deploy)
Entry: `k8s/pipeline/` (`cd_deploy.sh`-style). Steps: checkout main → load secrets → cloud auth +
`make k8s -- kubeconfig` → `kubectl get ns` → **`make k8s -- upgrade`** (`helmfile apply`); first-ever
deploy uses `make k8s -- install` (`helmfile sync`). Optionally scope with `-l <chart>` for targeted rollout. Pin
`ARTIFACTS_VERSION` per release for reproducibility.

## Notes
- Container image + shared scripts live under `k8s/pipeline/` (Dockerfile + scaffolds).
- Use `-y` in automation to skip the interactive confirmations the CLIs add for humans — but only in CI
  where the `diff` gate already ran.
- Phase 1 (infra) is generally **not** part of the per-PR pipeline; it's applied deliberately by an
  operator (`iac.sh`) since it touches cloud state and `0-foundation` is LOCAL state.
