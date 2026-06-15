# Alert simulation specs

Human-owned, directly editable specs that describe **how to make each alert fire** in the cluster
and **what signal to look for in Zenduty**. Edit these by hand as you add
application-specific alerts.

> [!NOTE]
> The Claude alert-loop tooling that used to consume these specs (`/simulate`, `/verify-alert`,
> `/alert-loop`, `/fix-alert-query` commands and the `scenario-simulator` agent) has been **removed**.
> These specs and the alert rules remain; run the loop manually — deploy the backend, apply the
> scenario below in the cluster, then confirm in Zenduty with `scripts/zenduty.py` (needs
> `ZENDUTY_API_TOKEN`).

## Layout

One YAML file per alert **group**, mirroring the rule groups in
`../../iac/2-app/2-alerts/common/rules/`:

```
iac/2-app/2-alerts/common/rules/k8s.json   ->   test/alert-sim/k8s.yaml
iac/2-app/2-alerts/common/rules/<svc>.json ->   test/alert-sim/<svc>.yaml
```

When you add a rule, add a matching scenario in the same-named file here so it can be proven to fire.
A rule with no scenario can't be verified end-to-end.

## Schema

```yaml
defaults:
  namespace: alert-sim          # throwaway namespace the simulator uses
  match_field: alert            # how to match the Zenduty incident (the rule's `alert` name)

scenarios:
  - rule: <alert-name>          # must equal an `alert` in the matching rules/*.json
    group: <group>.json         # the rule group file this belongs to
    wait: 4m                    # rule `for` + eval interval + backend lag before it can fire
    match: <substring>          # optional; defaults to the rule name. Substring sought in the incident
    trigger:                    # ordered kubectl steps that induce the failure
      - <shell command>
      - |
        <multi-line heredoc for manifests>
    cleanup:                    # ordered steps to undo the simulation
      - <shell command>
    note: >                     # optional human notes (e.g. tuning thresholds)
      ...
```

### Conventions for complex / app-specific alerts

- Keep each `trigger` self-contained and idempotent (e.g. `create ns --dry-run | apply -f -`).
- Prefer inline heredoc manifests so the whole scenario is readable in one place.
- If a simulation needs a helper manifest too large to inline, put it next to this file under
  `test/alert-sim/manifests/<group>/<rule>.yaml` and reference it from the `trigger` with
  `kubectl apply -f test/alert-sim/manifests/<group>/<rule>.yaml`.
- `wait` must cover the rule's `for:` plus the group `interval:` plus backend evaluation lag. When
  unsure, over-estimate; the verify step polls up to a timeout anyway.
- Always provide `cleanup` so the loop leaves the cluster as it found it.
