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
# Drop make's "Entering/Leaving directory" chatter so the scripts' own (colorized) output and the
# failure summary below are what the user actually sees.
MAKEFLAGS += --no-print-directory
.PHONY: help iac k8s bringup status prereqs prereqs-check

# Recognized verbs — used by the catch-all (%:) to tell a typo'd verb from tokens being forwarded
# after `--`. Keep in sync with the targets above.
KNOWN := help iac k8s bringup status prereqs prereqs-check

# Forward everything after the verb (`make iac -- plan -l …` -> `scripts/iac.sh plan -l …`).
PASS = $(filter-out $@,$(MAKECMDGOALS))

# Surface a clear, attributed failure instead of just the bare `make: *** [Makefile:NN: <t>] Error N`
# (which is what makes "make error" feel opaque). The underlying script already prints a ❌ line; this
# adds which verb failed + how to get usage, then re-exits the real code. Append `|| $(FAIL)` to a recipe.
# $$@ is the failing target; evaluated in the recipe shell.
FAIL = { rc=$$?; echo "" >&2; echo "✗ 'make $@' failed (exit $$rc) — see the message above; run 'make $@ -- --help' for usage." >&2; exit $$rc; }

help: ## Show this help
	@c=""; r=""; if [ -t 1 ] && [ -z "$$NO_COLOR" ] && [ "$${TERM:-dumb}" != dumb ]; then c="$$(printf '\033[36m')"; r="$$(printf '\033[0m')"; fi; \
	  grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk -v c="$$c" -v r="$$r" 'BEGIN{FS=":.*?## "}{printf "  %s%-14s%s %s\n", c, $$1, r, $$2}'
	@echo ""
	@echo "Put '--' before CLI args so make passes -l/-c/-e flags through:"
	@echo "  make iac -- config -c gcp -e dev      make iac -- plan -l 1-platform.1-k8s"
	@echo "  make k8s -- kubeconfig                make k8s -- upgrade -l router"
	@echo ""
	@echo "Passing flags: they MUST follow '--'  ->  make <verb> -- <flags>.  'make <verb> --help'"
	@echo "  does NOT work (make prints its own help) — use 'make <verb> -- --help', or skip make:"
	@echo "  scripts/<verb>.sh --help   (no '--' needed)."

iac: ## Run the Phase-1 CLI, e.g. make iac -- plan -l 1-platform.1-k8s
	@$(CURDIR)/scripts/iac.sh $(PASS) || $(FAIL)

k8s: ## Run the Phase-2 CLI, e.g. make k8s -- upgrade -l router
	@$(CURDIR)/scripts/k8s.sh $(PASS) || $(FAIL)

bringup: ## End-to-end bringup (all IaC layers + kubeconfig + helm install) / status, e.g. make bringup -- run -c azure -e sandbox -y
	@$(CURDIR)/scripts/bringup.sh $(PASS) || $(FAIL)

status: ## Bringup progress table (scripts/status.sh, reads the step ledger), e.g. make status / make status -- -w -i 30 (watch, refresh 30s)
	@$(CURDIR)/scripts/status.sh $(PASS) || $(FAIL)

prereqs: ## Install/verify the pinned toolchain (tofu, terragrunt, helm, helmfile, plugins, ...)
	@scripts/install-prerequisites.sh $(PASS) || $(FAIL)

prereqs-check: ## Verify the toolchain only (no install; non-zero exit if gaps)
	@scripts/install-prerequisites.sh --check $(PASS) || $(FAIL)

# Catch-all for the words after `make <verb> -- …` (they're goals to make; the verb's recipe already
# consumed them via $(PASS)). Must stay last; explicit targets above take precedence.
# If a real verb IS among the goals, these are forwarded flags — stay silent. If NOT (a typo'd or
# unknown verb, the only forgotten-`--` case that reaches us — make pre-empts `--help`/`--flag`
# itself), print a clear hint instead of silently doing nothing.
%:
	@if [ -z "$(filter $(KNOWN),$(MAKECMDGOALS))" ]; then \
	  echo "✗ '$(MAKECMDGOALS)': not a divyam-deployment command. Flags must follow a verb AND '--':" >&2; \
	  echo "    make <verb> -- <flags>     e.g. make iac -- plan -l 1-platform   |   make k8s -- diff" >&2; \
	  echo "  For help without '--', call the script directly:  scripts/<verb>.sh --help" >&2; \
	  echo "  Verbs: $(KNOWN)" >&2; \
	  exit 2; \
	fi
