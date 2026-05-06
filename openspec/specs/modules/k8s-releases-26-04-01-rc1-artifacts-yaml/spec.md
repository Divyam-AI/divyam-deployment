# k8s-releases-26-04-01-rc1-artifacts-yaml Module Specification

## Purpose

Define per-validation-case behavior contract for `k8s/releases/26.04.01-rc1-artifacts.yaml`.

## Requirements

### Requirement: YAML validation command cases
`k8s/releases/26.04.01-rc1-artifacts.yaml` SHALL remain parseable and executable in each pipeline step that references it.

#### Scenario: artifact_schema_case
- **WHEN** artifact list in `k8s/releases/26.04.01-rc1-artifacts.yaml` is consumed by `/ci_deploy/run_steps.py --yaml_file k8s/releases/26.04.01-rc1-artifacts.yaml`
- **THEN** artifact names, manifest paths, and workflow sections resolve without key lookup errors.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `k8s/releases/26.04.01-rc1-artifacts.yaml`
  gap_action: Add a concrete validation command that verifies this file contract in CI.

- verification_status: coverage_gap
  evidence_type: pipeline_step
  evidence_ref: Artifact contract reference: `k8s/releases/26.04.01-rc1-artifacts.yaml`
  artifact_ref: k8s/releases/26.04.01-rc1-artifacts.yaml
  gap_action: Add or bind this pipeline step to an executable workflow assertion.

- verification_status: coverage_gap
  evidence_type: pipeline_step
  evidence_ref: Artifact contract reference: `/ci_deploy/run_steps.py --yaml_file k8s/releases/26.04.01-rc1-artifacts.yaml`
  artifact_ref: /ci_deploy/run_steps.py --yaml_file k8s/releases/26.04.01-rc1-artifacts.yaml
  gap_action: Add or bind this pipeline step to an executable workflow assertion.

- verification_status: coverage_gap
  evidence_type: command_case
  evidence_ref: Scenario `artifact_schema_case` command: `/ci_deploy/run_steps.py --yaml_file k8s/releases/26.04.01-rc1-artifacts.yaml`
  artifact_ref: artifacts.yaml
  gap_action: Implement this command case in an executable workflow and capture pass/fail evidence.
