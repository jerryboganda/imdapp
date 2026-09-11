# =============================================================================
# imdapp - control plane convenience targets.
# Every compute target dispatches to GitHub Actions. Nothing computes locally.
# =============================================================================
SHELL := /bin/bash
REPO  ?= jerryboganda/imdapp
TASK  ?= full
BOARD ?= misc

.PHONY: help bootstrap verify dispatch compute healthcheck mcp-smoke toolcheck kb-audit tests site-build release-check full ci-status

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Prepare the thin client (no compute)
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-local.ps1 || bash scripts/bootstrap-local.sh

verify: ## Read-only repository integration check
	bash scripts/verify-integrations.sh

dispatch: ## Dispatch an arbitrary task: make dispatch TASK=full BOARD=misc
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh $(TASK) $(BOARD)

healthcheck:  ## Run healthcheck on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh healthcheck
mcp-smoke:    ## Run MCP smoke on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh mcp-smoke
toolcheck:    ## Run toolcheck on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh toolcheck $(BOARD)
kb-audit:     ## Run KB audit on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh kb-audit
tests:        ## Run unit tests on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh tests
site-build:   ## Build the docs site on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh site-build
release-check: ## Run public release check on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh release-check
full:         ## Run the full compute pipeline on Actions
	IMDAPP_REPO=$(REPO) bash scripts/compute.sh full

ci-status: ## Show recent workflow runs
	gh run list --repo $(REPO) --limit 10
