# =============================================================================
# Makefile – Devcontainer Toolkit
# =============================================================================
# Targets:
#   make test                Run the full test suite (base + features)
#   make test-base           Test the base image only
#   make test-features       Test all features only
#   make test-dbt-duckdb     Test a single feature
#   make lint                Run all linters
#   make fmt                 Format all files in-place
#   make fmt-check           Check formatting without modifying files
#   make check               Run lint + fmt-check (CI-friendly)
#   make install-tools       Install linting/formatting tools
#   make clean               Remove test images
# =============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Tool paths (overridable)
SHELLCHECK ?= shellcheck
SHFMT      ?= shfmt
HADOLINT   ?= hadolint

# shfmt style: indent=4, binary ops start of line, case indent, redirect follow
SHFMT_FLAGS := -i 4 -bn -ci -sr

# File lists
SHELL_SCRIPTS := $(shell find . -name '*.sh' -not -path './.git/*')
DOCKERFILES   := $(shell find . -name 'Dockerfile' -not -path './.git/*')
JSON_FILES    := $(shell find . -name '*.json' -not -path './.git/*' -not -path './node_modules/*')

# Colours
_cyan  := \033[0;36m
_green := \033[0;32m
_reset := \033[0m

# =============================================================================
# Help
# =============================================================================

.PHONY: help
help: ## Show this help
	@echo -e "$(_cyan)Devcontainer Toolkit$(_reset)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[0;33m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# =============================================================================
# Tests
# =============================================================================

.PHONY: test test-base test-features test-dbt-duckdb test-k8s-tools test-postgres-client

test: ## Run the full test suite (base + all features)
	@./tests/test.sh all

test-base: ## Test the base image only
	@./tests/test.sh base

test-features: ## Test all features (without base tool checks)
	@./tests/test.sh features

test-dbt-duckdb: ## Test the dbt-duckdb feature
	@./tests/test.sh dbt-duckdb

test-k8s-tools: ## Test the k8s-tools feature
	@./tests/test.sh k8s-tools

test-postgres-client: ## Test the postgres-client feature
	@./tests/test.sh postgres-client

# =============================================================================
# Linting
# =============================================================================

.PHONY: lint lint-shell lint-docker lint-json

lint: lint-shell lint-docker lint-json ## Run all linters

lint-shell: ## Lint shell scripts with shellcheck
	@echo -e "$(_cyan)Linting shell scripts...$(_reset)"
	@$(SHELLCHECK) $(SHELL_SCRIPTS)
	@echo -e "$(_green)shellcheck passed.$(_reset)"

lint-docker: ## Lint Dockerfiles with hadolint
	@echo -e "$(_cyan)Linting Dockerfiles...$(_reset)"
	@if command -v $(HADOLINT) > /dev/null 2>&1; then \
		$(HADOLINT) $(DOCKERFILES); \
		echo -e "$(_green)hadolint passed.$(_reset)"; \
	else \
		echo "  hadolint not found – run 'make install-tools' to install it."; \
		exit 1; \
	fi

lint-json: ## Validate JSON files with jq (skips JSONC files with comments)
	@echo -e "$(_cyan)Validating JSON files...$(_reset)"
	@fail=0; \
	for f in $(JSON_FILES); do \
		if grep -qE '^\s*//' "$$f" 2>/dev/null; then \
			echo "  SKIP (JSONC): $$f"; \
			continue; \
		fi; \
		if ! jq empty "$$f" 2>/dev/null; then \
			echo "  INVALID: $$f"; \
			fail=1; \
		fi; \
	done; \
	if [ "$$fail" -eq 0 ]; then \
		echo -e "$(_green)All JSON files valid.$(_reset)"; \
	else \
		exit 1; \
	fi

# =============================================================================
# Formatting
# =============================================================================

.PHONY: fmt fmt-check fmt-shell fmt-shell-check

fmt: fmt-shell ## Format all files in-place

fmt-check: fmt-shell-check ## Check formatting without modifying files (CI-friendly)

fmt-shell: ## Format shell scripts in-place with shfmt
	@echo -e "$(_cyan)Formatting shell scripts...$(_reset)"
	@$(SHFMT) -w $(SHFMT_FLAGS) $(SHELL_SCRIPTS)
	@echo -e "$(_green)Shell scripts formatted.$(_reset)"

fmt-shell-check: ## Check shell script formatting (non-destructive)
	@echo -e "$(_cyan)Checking shell script formatting...$(_reset)"
	@$(SHFMT) -d $(SHFMT_FLAGS) $(SHELL_SCRIPTS)
	@echo -e "$(_green)Shell scripts correctly formatted.$(_reset)"

# =============================================================================
# Combined CI check
# =============================================================================

.PHONY: check
check: lint fmt-check ## Run all linters and format checks (CI target)

# =============================================================================
# Tool Installation
# =============================================================================

HADOLINT_VERSION ?= 2.12.0

.PHONY: install-tools
install-tools: ## Install linting/formatting tools
	@echo -e "$(_cyan)Installing linting tools...$(_reset)"
	@# shellcheck
	@if ! command -v shellcheck > /dev/null 2>&1; then \
		echo "  Installing shellcheck..."; \
		sudo apt-get update -y && sudo apt-get install -y shellcheck; \
	else \
		echo "  shellcheck already installed."; \
	fi
	@# shfmt
	@if ! command -v shfmt > /dev/null 2>&1; then \
		echo "  Installing shfmt..."; \
		GOBIN=/usr/local/bin go install mvdan.cc/sh/v3/cmd/shfmt@latest 2>/dev/null || \
		{ curl -fsSL "https://github.com/mvdan/sh/releases/download/v3.10.0/shfmt_v3.10.0_linux_amd64" -o /usr/local/bin/shfmt && chmod +x /usr/local/bin/shfmt; }; \
	else \
		echo "  shfmt already installed."; \
	fi
	@# hadolint
	@if ! command -v hadolint > /dev/null 2>&1; then \
		echo "  Installing hadolint..."; \
		sudo curl -fsSL "https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint && \
		sudo chmod +x /usr/local/bin/hadolint; \
	else \
		echo "  hadolint already installed."; \
	fi
	@echo -e "$(_green)All tools installed.$(_reset)"

# =============================================================================
# Cleanup
# =============================================================================

.PHONY: clean
clean: ## Remove test images
	@echo "Removing test images..."
	@docker rmi -f \
		devcontainer-base:test \
		devcontainer-feature-dbt-duckdb:test \
		devcontainer-feature-k8s-tools:test \
		devcontainer-feature-postgres-client:test \
		devcontainer-all-features:test \
		> /dev/null 2>&1 || true
	@echo "Done."
