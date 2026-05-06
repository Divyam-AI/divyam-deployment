# iac-1-platform-0-app-gw-gcp-terragrunt-hcl Module Specification

## Purpose

Define per-validation-case behavior contract for `iac/1-platform/0-app_gw/gcp/terragrunt.hcl`.

## Requirements

### Requirement: IaC static validation command cases
`iac/1-platform/0-app_gw/gcp/terragrunt.hcl` SHALL keep Terraform/Terragrunt syntax and reference contracts valid for module directory `iac/1-platform/0-app_gw/gcp`.

### Requirement: Coverage-gap closure command cases
No direct automated case currently asserts `iac/1-platform/0-app_gw/gcp/terragrunt.hcl` behavior; these concrete cases SHALL be added.

#### Scenario: proposed_tg_hclfmt_iac_1_platform_0_app_gw_gcp_terragrunt_hcl
- **WHEN** CI executes proposed case `proposed_tg_hclfmt_iac_1_platform_0_app_gw_gcp_terragrunt_hcl`
- **THEN** command `terragrunt hclfmt --terragrunt-working-dir iac/1-platform/0-app_gw/gcp` validates `iac/1-platform/0-app_gw/gcp/terragrunt.hcl` directly.

#### Scenario: proposed_tg_validate_iac_1_platform_0_app_gw_gcp_terragrunt_hcl
- **WHEN** CI executes proposed case `proposed_tg_validate_iac_1_platform_0_app_gw_gcp_terragrunt_hcl`
- **THEN** command `terragrunt validate --terragrunt-working-dir iac/1-platform/0-app_gw/gcp` validates `iac/1-platform/0-app_gw/gcp/terragrunt.hcl` directly.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `iac/1-platform/0-app_gw/gcp/terragrunt.hcl`
  gap_action: Add a concrete validation command that verifies this file contract in CI.

- verification_status: coverage_gap
  evidence_type: command_case
  evidence_ref: Scenario `proposed_tg_hclfmt_iac_1_platform_0_app_gw_gcp_terragrunt_hcl` command: `terragrunt hclfmt --terragrunt-working-dir iac/1-platform/0-app_gw/gcp`
  gap_action: Implement this command case in an executable workflow and capture pass/fail evidence.

- verification_status: coverage_gap
  evidence_type: command_case
  evidence_ref: Scenario `proposed_tg_validate_iac_1_platform_0_app_gw_gcp_terragrunt_hcl` command: `terragrunt validate --terragrunt-working-dir iac/1-platform/0-app_gw/gcp`
  gap_action: Implement this command case in an executable workflow and capture pass/fail evidence.
