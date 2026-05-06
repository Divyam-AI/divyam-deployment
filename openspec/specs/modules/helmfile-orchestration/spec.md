# helmfile-orchestration Module Specification

## Purpose

Define behavior contracts for Kubernetes deployment orchestration in `k8s/helmfile.yaml.gotmpl` and supporting values/release artifacts.

## Requirements

### Requirement: Deterministic artifact resolution
Helmfile execution SHALL resolve artifacts in documented order using `ARTIFACTS_VERSION`, local `artifacts.yaml`, or latest release artifact file.

### Requirement: Values precedence
Deployment values SHALL preserve precedence `config.yaml` > `resources.yaml` > `artifacts.yaml`.

### Requirement: Safe diff/apply lifecycle
Operators and pipelines SHALL use `diff` for preview and `apply`/`sync` according to deployment phase guidance.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `k8s/helmfile.yaml.gotmpl`
  gap_action: Add a concrete validation command that verifies this file contract in CI.

- verification_status: coverage_gap
  evidence_type: pipeline_step
  evidence_ref: Artifact contract reference: `artifacts.yaml`
  artifact_ref: artifacts.yaml
  gap_action: Add or bind this pipeline step to an executable workflow assertion.
