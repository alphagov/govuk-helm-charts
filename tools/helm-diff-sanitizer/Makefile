# Helm Diff Sanitizer Makefile
# Provides comprehensive developer experience for secure Helm diff operations

# =============================================================================
# Configuration Variables
# =============================================================================

# Application Configuration
APP_NAME := helm-diff-sanitizer
SANITIZER_BINARY := ./$(APP_NAME)
GO_VERSION := 1.24

# Build Configuration
GOOS := $(shell go env GOOS)
GOARCH := $(shell go env GOARCH)
CI_GOOS := linux
CI_GOARCH := amd64

# Helm Configuration (can be overridden)
RELEASE_NAME ?= myapp
NAMESPACE ?= default
CHART_PATH ?= ./chart
VALUES_FILE ?= values.yaml
SANITIZED_VALUES_FILE ?= values-sanitized.yaml

# Output Configuration
DIFF_OUTPUT_FILE ?= helm-diff-output.txt
SANITIZED_DIFF_FILE ?= helm-diff-sanitized.txt

# Dependencies
REQUIRED_TOOLS := helm go
HELM_PLUGINS := diff

# =============================================================================
# Color Configuration
# =============================================================================

# ANSI Color Codes
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
NC := \033[0m # No Color

# Color Functions
define print_success
	@echo "$(GREEN)✓ $(1)$(NC)"
endef

define print_info
	@echo "$(BLUE)ℹ $(1)$(NC)"
endef

define print_warning
	@echo "$(YELLOW)⚠ $(1)$(NC)"
endef

define print_error
	@echo "$(RED)✗ $(1)$(NC)"
endef

define print_header
	@echo "$(PURPLE)=== $(1) ===$(NC)"
endef

# =============================================================================
# Default Target
# =============================================================================

.DEFAULT_GOAL := help

# =============================================================================
# Help Target
# =============================================================================

.PHONY: help
help: ## Show this help message
	@echo "$(WHITE)Helm Diff Sanitizer - Developer Commands$(NC)"
	@echo ""
	@echo "$(CYAN)Usage:$(NC) make [target] [VARIABLE=value]"
	@echo ""
	@echo "$(CYAN)Core Targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E '^(help|build|build-ci|clean|test):' | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)Helm Operations:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E '^(helm-diff|helm-diff-ci|sanitize-values|validate-chart):' | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)Development & Security:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E '^(install-deps|security-check|show-config):' | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)Configuration Variables:$(NC)"
	@echo "  $(YELLOW)RELEASE_NAME$(NC)    = $(RELEASE_NAME)"
	@echo "  $(YELLOW)NAMESPACE$(NC)       = $(NAMESPACE)"
	@echo "  $(YELLOW)CHART_PATH$(NC)      = $(CHART_PATH)"
	@echo "  $(YELLOW)VALUES_FILE$(NC)     = $(VALUES_FILE)"
	@echo ""
	@echo "$(CYAN)Examples:$(NC)"
	@echo "  make build"
	@echo "  make helm-diff RELEASE_NAME=myapp NAMESPACE=staging"
	@echo "  make sanitize-values VALUES_FILE=production-values.yaml"
	@echo "  make security-check"

# =============================================================================
# Core Targets
# =============================================================================

.PHONY: build
build: ## Build the Go binary for current platform
	$(call print_header,Building $(APP_NAME) for $(GOOS)/$(GOARCH))
	@if ! command -v go >/dev/null 2>&1; then \
		$(call print_error,Go is not installed or not in PATH); \
		exit 1; \
	fi
	@$(call print_info,Building binary...)
	@GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(APP_NAME) \
		-ldflags "-X main.version=$$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')" \
		|| { $(call print_error,Build failed); exit 1; }
	@$(call print_success,Binary built successfully: $(SANITIZER_BINARY))
	@ls -la $(APP_NAME)

.PHONY: build-ci
build-ci: ## Build optimized binary for CI (Linux/AMD64)
	$(call print_header,Building $(APP_NAME) for CI ($(CI_GOOS)/$(CI_GOARCH)))
	@if ! command -v go >/dev/null 2>&1; then \
		$(call print_error,Go is not installed or not in PATH); \
		exit 1; \
	fi
	@$(call print_info,Building optimized CI binary...)
	@CGO_ENABLED=0 GOOS=$(CI_GOOS) GOARCH=$(CI_GOARCH) go build \
		-a -installsuffix cgo \
		-ldflags "-s -w -X main.version=$$(git describe --tags --always --dirty 2>/dev/null || echo 'ci')" \
		-o $(APP_NAME)-$(CI_GOOS)-$(CI_GOARCH) \
		|| { $(call print_error,CI build failed); exit 1; }
	@$(call print_success,CI binary built successfully: $(APP_NAME)-$(CI_GOOS)-$(CI_GOARCH))
	@ls -la $(APP_NAME)-$(CI_GOOS)-$(CI_GOARCH)

.PHONY: clean
clean: ## Clean all build artifacts and temporary files
	$(call print_header,Cleaning build artifacts)
	@$(call print_info,Removing binaries...)
	@rm -f $(APP_NAME) $(APP_NAME)-* 2>/dev/null || true
	@$(call print_info,Removing temporary files...)
	@rm -f $(DIFF_OUTPUT_FILE) $(SANITIZED_DIFF_FILE) $(SANITIZED_VALUES_FILE) 2>/dev/null || true
	@rm -f helm-diff-sanitizer-*.yaml 2>/dev/null || true
	@rm -rf dist/ 2>/dev/null || true
	@$(call print_success,Clean completed)

.PHONY: test
test: ## Run Go tests
	$(call print_header,Running Go tests)
	@if ! command -v go >/dev/null 2>&1; then \
		$(call print_error,Go is not installed or not in PATH); \
		exit 1; \
	fi
	@$(call print_info,Running unit tests...)
	@go test -v ./... || { $(call print_error,Tests failed); exit 1; }
	@$(call print_success,All tests passed)

# =============================================================================
# Helm Operations
# =============================================================================

.PHONY: helm-diff
helm-diff: build validate-inputs ## Run sanitized helm diff locally for development
	$(call print_header,Running Sanitized Helm Diff (Development))
	@$(call print_info,Configuration:)
	@echo "  Release: $(YELLOW)$(RELEASE_NAME)$(NC)"
	@echo "  Namespace: $(YELLOW)$(NAMESPACE)$(NC)"
	@echo "  Chart: $(YELLOW)$(CHART_PATH)$(NC)"
	@echo "  Values: $(YELLOW)$(VALUES_FILE)$(NC)"
	@echo ""
	@$(call print_info,Running helm diff with sanitization...)
	@$(SANITIZER_BINARY) diff $(RELEASE_NAME) $(NAMESPACE) $(CHART_PATH) $(VALUES_FILE) || \
		{ $(call print_error,Helm diff failed); exit 1; }
	@$(call print_success,Helm diff completed successfully)

.PHONY: helm-diff-ci
helm-diff-ci: build validate-inputs ## Run helm diff for CI (outputs to file)
	$(call print_header,Running Sanitized Helm Diff (CI))
	@$(call print_info,Configuration:)
	@echo "  Release: $(YELLOW)$(RELEASE_NAME)$(NC)"
	@echo "  Namespace: $(YELLOW)$(NAMESPACE)$(NC)"
	@echo "  Chart: $(YELLOW)$(CHART_PATH)$(NC)"
	@echo "  Values: $(YELLOW)$(VALUES_FILE)$(NC)"
	@echo "  Output: $(YELLOW)$(SANITIZED_DIFF_FILE)$(NC)"
	@echo ""
	@$(call print_info,Running helm diff and saving to file...)
	@$(SANITIZER_BINARY) diff $(RELEASE_NAME) $(NAMESPACE) $(CHART_PATH) $(VALUES_FILE) > $(SANITIZED_DIFF_FILE) || \
		{ $(call print_error,Helm diff failed); exit 1; }
	@$(call print_success,Sanitized diff saved to: $(SANITIZED_DIFF_FILE))
	@wc -l $(SANITIZED_DIFF_FILE) | awk '{print "  Lines: " $$1}'

.PHONY: sanitize-values
sanitize-values: build ## Create sanitized version of values file
	$(call print_header,Sanitizing Values File)
	@if [ ! -f "$(VALUES_FILE)" ]; then \
		$(call print_error,Values file not found: $(VALUES_FILE)); \
		exit 1; \
	fi
	@$(call print_info,Sanitizing $(VALUES_FILE) -> $(SANITIZED_VALUES_FILE))
	@$(SANITIZER_BINARY) sanitize-values $(VALUES_FILE) $(SANITIZED_VALUES_FILE) || \
		{ $(call print_error,Values sanitization failed); exit 1; }
	@$(call print_success,Values file sanitized successfully)
	@echo "  Original: $$(wc -l < $(VALUES_FILE)) lines"
	@echo "  Sanitized: $$(wc -l < $(SANITIZED_VALUES_FILE)) lines"

.PHONY: validate-chart
validate-chart: ## Validate Helm chart syntax
	$(call print_header,Validating Helm Chart)
	@if ! command -v helm >/dev/null 2>&1; then \
		$(call print_error,Helm is not installed or not in PATH); \
		exit 1; \
	fi
	@if [ ! -d "$(CHART_PATH)" ]; then \
		$(call print_error,Chart directory not found: $(CHART_PATH)); \
		exit 1; \
	fi
	@$(call print_info,Validating chart syntax...)
	@helm lint $(CHART_PATH) || { $(call print_error,Chart validation failed); exit 1; }
	@$(call print_info,Validating chart template rendering...)
	@helm template test-release $(CHART_PATH) --dry-run >/dev/null || \
		{ $(call print_error,Template rendering failed); exit 1; }
	@$(call print_success,Chart validation completed successfully)

# =============================================================================
# Development & Security
# =============================================================================

.PHONY: install-deps
install-deps: ## Install required dependencies (helm, helm-diff plugin)
	$(call print_header,Installing Dependencies)
	@$(call print_info,Checking required tools...)
	@for tool in $(REQUIRED_TOOLS); do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			$(call print_error,$$tool is not installed); \
			echo "  Please install $$tool and try again"; \
			exit 1; \
		else \
			$(call print_success,$$tool is available); \
		fi; \
	done
	@$(call print_info,Checking Helm plugins...)
	@if ! helm plugin list | grep -q "diff"; then \
		$(call print_info,Installing helm-diff plugin...); \
		helm plugin install https://github.com/databus23/helm-diff || \
			{ $(call print_error,Failed to install helm-diff plugin); exit 1; }; \
		$(call print_success,helm-diff plugin installed); \
	else \
		$(call print_success,helm-diff plugin is already installed); \
	fi
	@$(call print_success,All dependencies are ready)

.PHONY: security-check
security-check: build ## Validate no sensitive data leaks in output
	$(call print_header,Security Validation)
	@$(call print_info,Creating test values file with sensitive data...)
	@echo 'database:' > test-values.yaml
	@echo '  password: "super-secret-password"' >> test-values.yaml
	@echo '  apiKey: "sk-1234567890abcdef1234567890abcdef"' >> test-values.yaml
	@echo '  token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"' >> test-values.yaml
	@echo 'secrets:' >> test-values.yaml
	@echo '  privateKey: "-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC..."' >> test-values.yaml
	@$(call print_info,Testing sanitization...)
	@$(SANITIZER_BINARY) sanitize-values test-values.yaml test-values-sanitized.yaml
	@$(call print_info,Checking for sensitive data leaks...)
	@if grep -i "super-secret-password\|sk-1234567890\|eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\|-----BEGIN PRIVATE KEY-----" test-values-sanitized.yaml >/dev/null; then \
		$(call print_error,SECURITY VIOLATION: Sensitive data found in sanitized output!); \
		echo "Sanitized file contents:"; \
		cat test-values-sanitized.yaml; \
		rm -f test-values.yaml test-values-sanitized.yaml; \
		exit 1; \
	fi
	@$(call print_success,Security check passed - no sensitive data leaked)
	@$(call print_info,Sanitized output preview:)
	@cat test-values-sanitized.yaml | head -10
	@rm -f test-values.yaml test-values-sanitized.yaml
	@$(call print_success,Security validation completed)

.PHONY: show-config
show-config: ## Display current configuration
	$(call print_header,Current Configuration)
	@echo "$(CYAN)Application:$(NC)"
	@echo "  Name: $(YELLOW)$(APP_NAME)$(NC)"
	@echo "  Binary: $(YELLOW)$(SANITIZER_BINARY)$(NC)"
	@echo "  Go Version: $(YELLOW)$(GO_VERSION)$(NC)"
	@echo ""
	@echo "$(CYAN)Build Configuration:$(NC)"
	@echo "  Current Platform: $(YELLOW)$(GOOS)/$(GOARCH)$(NC)"
	@echo "  CI Platform: $(YELLOW)$(CI_GOOS)/$(CI_GOARCH)$(NC)"
	@echo ""
	@echo "$(CYAN)Helm Configuration:$(NC)"
	@echo "  Release Name: $(YELLOW)$(RELEASE_NAME)$(NC)"
	@echo "  Namespace: $(YELLOW)$(NAMESPACE)$(NC)"
	@echo "  Chart Path: $(YELLOW)$(CHART_PATH)$(NC)"
	@echo "  Values File: $(YELLOW)$(VALUES_FILE)$(NC)"
	@echo "  Sanitized Values: $(YELLOW)$(SANITIZED_VALUES_FILE)$(NC)"
	@echo ""
	@echo "$(CYAN)Output Files:$(NC)"
	@echo "  Diff Output: $(YELLOW)$(DIFF_OUTPUT_FILE)$(NC)"
	@echo "  Sanitized Diff: $(YELLOW)$(SANITIZED_DIFF_FILE)$(NC)"
	@echo ""
	@echo "$(CYAN)Tool Status:$(NC)"
	@for tool in $(REQUIRED_TOOLS); do \
		if command -v $$tool >/dev/null 2>&1; then \
			echo "  $(GREEN)✓$(NC) $$tool: $$($$tool version 2>/dev/null | head -1 || echo 'installed')"; \
		else \
			echo "  $(RED)✗$(NC) $$tool: not found"; \
		fi; \
	done
	@if command -v helm >/dev/null 2>&1; then \
		if helm plugin list | grep -q "diff"; then \
			echo "  $(GREEN)✓$(NC) helm-diff plugin: installed"; \
		else \
			echo "  $(RED)✗$(NC) helm-diff plugin: not installed"; \
		fi; \
	fi

# =============================================================================
# Internal Helper Targets
# =============================================================================

.PHONY: validate-inputs
validate-inputs:
	@$(call print_info,Validating inputs...)
	@if [ ! -d "$(CHART_PATH)" ]; then \
		$(call print_error,Chart directory not found: $(CHART_PATH)); \
		exit 1; \
	fi
	@if [ ! -f "$(VALUES_FILE)" ]; then \
		$(call print_error,Values file not found: $(VALUES_FILE)); \
		exit 1; \
	fi
	@if [ ! -f "$(SANITIZER_BINARY)" ]; then \
		$(call print_error,Sanitizer binary not found. Run 'make build' first); \
		exit 1; \
	fi
	@if ! command -v helm >/dev/null 2>&1; then \
		$(call print_error,Helm is not installed. Run 'make install-deps' first); \
		exit 1; \
	fi
	@if ! helm plugin list | grep -q "diff"; then \
		$(call print_error,helm-diff plugin not found. Run 'make install-deps' first); \
		exit 1; \
	fi
	@$(call print_success,All inputs validated)

# =============================================================================
# Phony Targets Declaration
# =============================================================================

.PHONY: all clean build build-ci test help install-deps security-check show-config
.PHONY: helm-diff helm-diff-ci sanitize-values validate-chart validate-inputs