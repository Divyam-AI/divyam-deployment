---
description: Authenticate to the cloud and (re)fetch the cluster kubeconfig, then verify reachability.
argument-hint: "[-c gcp|azure] [--cluster X] [--resource-group RG] [--project P] [--region R|--zone Z]"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(kubectl config:*), Skill
---
Use `divyam-tooling` (clouds.md). Fetch the cluster kubeconfig via the Makefile entrypoint with any
passed args: **$ARGUMENTS**

1. Run `make k8s -- kubeconfig $ARGUMENTS`. It resolves the cluster/RG/project from `terragrunt output`
   → `provider.yaml` → naming convention; only pass `--cluster`/`--resource-group`/`--project`/`--region`/
   `--zone` if resolution fails (or `--no-tf` to skip the terragrunt lookup).
2. **Cloud login is the user's job.** If Azure needs `az login` and `ARM_*` aren't set, ask the user to
   run `! az login` (or export the service principal) and stop — don't attempt interactive login.
3. On success, run `kubectl config current-context` and `kubectl get ns` and report the active context.
   If `get ns` fails, point to `divyam-deploy` → troubleshooting (network path / context / expired creds).
