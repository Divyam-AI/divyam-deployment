---
description: Apply the NAP NodePools (2-app/0-nap_configs) so Karpenter can schedule workloads, then verify NodePools exist and Pending pods start scheduling. (Azure)
argument-hint: "[env]"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(kubectl describe:*), Read, Skill
---
You ensure the cluster's **NAP/Karpenter NodePools** exist — without them every workload pod stays
`Pending` (`label "divyam.ai/nodepool-name" does not have known values`). Adopt
`divyam-platform-engineer`. Optional env arg: **$ARGUMENTS**. Azure-only (`0-nap_configs`); GCP uses
GKE node pools/Autopilot.

1. **Check current state.** `kubectl get nodepools.karpenter.sh -A` (or `kubectl get nodepool -A`).
   If the four pools (`cpu-ondemand`, `cpu-spot`, `gpu-ondemand`, `gpu-spot`) already exist, report and
   skip to step 4.
2. **Plan.** `make iac -- plan -l 2-app.0-nap_configs`; summarize (it creates `kubernetes_manifest`
   NodePool/NodeClass resources + the NVIDIA device plugin).
3. **Checkpoint → apply.** On go-ahead, `make iac -- apply -l 2-app.0-nap_configs`. It needs cluster
   reachability (kubeconfig) since it applies manifests via the kubernetes provider.
4. **Verify it took:**
   - `kubectl get nodepool -A` shows the pools.
   - If pods were Pending, confirm Karpenter reacts: `kubectl get nodeclaims` shows new claims and a
     previously-Pending pod's events show `Nominated`/`Scheduled` (describe it).
   - New nodes join within a few minutes (`kubectl get nodes`).
5. Report. If pods are still Pending after nodes are Ready, the selector/taint mismatch is elsewhere —
   hand to `/debug-stack`.
