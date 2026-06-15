---
description: Show bringup/IaC step progress from the ledger (status.sh), polling at an interval while a long run is in flight
argument-hint: "[gcp|azure] [env] [interval-seconds]"
allowed-tools: Bash, Read
---

Show divyam-stack bringup/IaC progress for cloud `$1`, env `$2`, polling every `$3` seconds
(default 60) while a long-running operation is in flight.

**Entry point: `make status`** (→ `scripts/status.sh`, the standalone ledger READER) — pass flags
after `--`: `make status -- -c $1 -e $2`. Cloud/env fall back to `$CLOUD_PROVIDER`/`$ENV`, then
`.iac.conf`, so plain `make status` works after `iac.sh config`. The table reads the step ledger
(`.bringup-status.<cloud>.<env>`, written by `bringup.sh` / `iac.sh` / `k8s.sh` via
`scripts/status-ledger.sh`) — it shows the pre-seeded bringup plan **plus any module-level step**
(e.g. `1-platform.2-monitoring`) that an individual `make iac -- apply -l <layer[.sub]>` stamped.
Cheap: no cloud calls, no terragrunt.

1. Run a **one-shot** render: `make status -- -c $1 -e $2`. Exit codes: 0 = all applied,
   1 = failed/running/pending, 2 = never run for that cloud/env.
2. Relay the table (STEP/STATUS/STARTED/ELAPSED/TYPICAL). Call out the step currently `running`
   (compare ELAPSED against TYPICAL), anything `failed`, and what's still `pending`.
3. If a long run is in flight, **ask the user (AskUserQuestion) whether they want a live watch in
   their own terminal** — if yes, hand them the one-liner with the default 30s refresh:
   `! make status -- -c $1 -e $2 -w -i 30`. Either way keep polling one-shots (step 4).
4. While the exit code is 1 and a long run (bringup, full-layer apply, install) is in flight,
   **poll**: re-run the one-shot at the interval (`$3`, default 60s) and relay changes. Stop when
   exit code is 0 (all applied — suggest `/cluster-status` next) or a step turns `failed`
   (surface it and offer `/debug-stack` or the failing layer's logs).
5. **When `k8s-install` turns `running`** (the table prints a hint), **ask (AskUserQuestion):
   track releases via terminal (helm TUI), web dashboard, or neither?**
   - **Terminal** → user-run only: `! make k8s -- status --tui` (interactive UI).
   - **Dashboard** → start it in the background
     (`nohup make k8s -- status --dashboard >/tmp/helm-dashboard.log 2>&1 &`); it binds
     `0.0.0.0:${HELM_DASHBOARD_PORT:-8080}` with no browser — give the printed URL (on a sandbox
     VM the laptop needs the subnet routed first, e.g. via `sshuttle`).
   - **Neither** → keep relaying the table.
6. **Never run `-w/--watch` or `--tui` yourself** — interactive loops that never return hang the
   tool shell; they belong in the user's terminal (the `!` prefix).
7. For machine-readable checks use `make status -- --porcelain` (`<step>=<state>` lines); never
   read the ledger file directly.

Read-only except the optional background dashboard server; never mutates infra or the ledger.
