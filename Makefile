# SPDX-License-Identifier: Apache-2.0
# Divyam deployment — toolchain setup + workflow commands.
#
# The workflows are two CLIs (scripts/iac.sh, scripts/k8s.sh) run via `make iac`/`make k8s`.
# IMPORTANT: put `--` before the CLI args, otherwise make swallows -l/-c/-e style flags:
#
#   make iac -- config -c gcp -e dev
#   make iac -- plan -l 1-platform.1-k8s
#   make k8s -- upgrade -l router
#   make k8s -- kubeconfig
#
# (Equivalent to running ./scripts/iac.sh / ./scripts/k8s.sh directly, which need no `--`.)

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
.PHONY: help iac k8s bringup status prereqs prereqs-check

help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Put '--' before CLI args so make passes -l/-c/-e flags through:"
	@echo "  make iac -- config -c gcp -e dev      make iac -- plan -l 1-platform.1-k8s"
	@echo "  make k8s -- kubeconfig                make k8s -- upgrade -l router"

iac: ## Run the Phase-1 CLI, e.g. make iac -- plan -l 1-platform.1-k8s
	@$(CURDIR)/scripts/iac.sh $(filter-out $@,$(MAKECMDGOALS))

k8s: ## Run the Phase-2 CLI, e.g. make k8s -- upgrade -l router
	@$(CURDIR)/scripts/k8s.sh $(filter-out $@,$(MAKECMDGOALS))

bringup: ## End-to-end bringup (all IaC layers + kubeconfig + helm install) / status, e.g. make bringup -- run -c azure -e sandbox -y
	@$(CURDIR)/scripts/bringup.sh $(filter-out $@,$(MAKECMDGOALS))

status: ## Bringup progress table (scripts/status.sh, reads the step ledger), e.g. make status / make status -- -w -i 30 (watch, refresh 30s)
	@$(CURDIR)/scripts/status.sh $(filter-out $@,$(MAKECMDGOALS))

prereqs: ## Install/verify the pinned toolchain (tofu, terragrunt, helm, helmfile, plugins, ...)
	scripts/install-prerequisites.sh

prereqs-check: ## Verify the toolchain only (no install; non-zero exit if gaps)
	scripts/install-prerequisites.sh --check

# Swallow the passthrough words (plan, -l, 1-platform.1-k8s, ...) as no-op goals so
# `make iac -- <args>` works. Must stay last; explicit targets above take precedence.
%:
	@:
