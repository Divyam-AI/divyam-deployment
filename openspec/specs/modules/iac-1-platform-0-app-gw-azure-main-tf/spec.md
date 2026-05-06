# iac-1-platform-0-app-gw-azure-main-tf Module Specification

## Purpose

Define per-validation-case behavior contract for `iac/1-platform/0-app_gw/azure/main.tf`.

## Requirements

### Requirement: IaC static validation command cases
`iac/1-platform/0-app_gw/azure/main.tf` SHALL keep Terraform/Terragrunt syntax and reference contracts valid for module directory `iac/1-platform/0-app_gw/azure`.

### Requirement: Coverage-gap closure command cases
No direct automated case currently asserts `iac/1-platform/0-app_gw/azure/main.tf` behavior; these concrete cases SHALL be added.

#### Scenario: proposed_tf_fmt_check_iac_1_platform_0_app_gw_azure_main_tf
- **WHEN** CI executes proposed case `proposed_tf_fmt_check_iac_1_platform_0_app_gw_azure_main_tf`
- **THEN** command `terraform fmt -check iac/1-platform/0-app_gw/azure` validates `iac/1-platform/0-app_gw/azure/main.tf` directly.

#### Scenario: proposed_tf_validate_iac_1_platform_0_app_gw_azure_main_tf
- **WHEN** CI executes proposed case `proposed_tf_validate_iac_1_platform_0_app_gw_azure_main_tf`
- **THEN** command `terraform -chdir=iac/1-platform/0-app_gw/azure init -backend=false && terraform -chdir=iac/1-platform/0-app_gw/azure validate` validates `iac/1-platform/0-app_gw/azure/main.tf` directly.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `iac/1-platform/0-app_gw/azure/main.tf`
  gap_action: Add a concrete validation command that verifies this file contract in CI.

- verification_status: coverage_gap
  evidence_type: command_case
  evidence_ref: Scenario `proposed_tf_fmt_check_iac_1_platform_0_app_gw_azure_main_tf` command: `terraform fmt -check iac/1-platform/0-app_gw/azure`
  gap_action: Implement this command case in an executable workflow and capture pass/fail evidence.

- verification_status: coverage_gap
  evidence_type: command_case
  evidence_ref: Scenario `proposed_tf_validate_iac_1_platform_0_app_gw_azure_main_tf` command: `terraform -chdir=iac/1-platform/0-app_gw/azure init -backend=false && terraform -chdir=iac/1-platform/0-app_gw/azure validate`
  gap_action: Implement this command case in an executable workflow and capture pass/fail evidence.
