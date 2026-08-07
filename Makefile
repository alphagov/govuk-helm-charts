SHELL=bash
.PHONY: check-yamllint lint check help enable-deployment-integration disable-deployment-integration enable-deployment-staging disable-deployment-staging enable-deployment-production disable-deployment-production

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: lint-yaml

check-yamllint: ## Check if yamllint is installed
	@if command -v yamllint >/dev/null 2>&1; then \
		echo "yamllint is already installed ($(shell yamllint --version))"; \
	else \
		echo "Please install yamllint before running this Makefile."; \
		exit 1; \
	fi


lint-yaml: check-yamllint ## Run yamllint on all YAML files
	@echo "Running yamllint..."
	yamllint -f github .

RENDERED_HELM_CHART_PATH := output
lint-helm:
	@EXITCODE=0; \
	shopt -s nullglob; \
	cd "$(RENDERED_HELM_CHART_PATH)"; \
	for values_file in values/*/*/*.yaml; do \
		echo "$${values_file}" | while IFS="/" read -r _ env chart app; do \
		  	echo "helm lint for $$app with chart $$chart"; \
			helm lint --quiet -f "$${values_file}" "raw-charts/$$chart/"; \
			if [[ $$? != 0 ]]; then \
				EXITCODE=1; \
			fi; \
		done; \
	done; \
	\
	for values_file in raw-charts/app-config/values-*.yaml; do \
  		echo "helm lint for app-config with $$values_file"; \
  		helm lint --quiet -f "$$values_file" raw-charts/app-config/; \
		if [[ $$? != 0 ]]; then \
			EXITCODE=1; \
		fi; \
  	done; \
  	exit "$$EXITCODE";



check: lint ## Alias for lint target

# Toggle deployment targets
enable-deployment-integration: ## Enable automatic deployments for integration
	cd bin/toggle-deployment && uv run toggle-deployment --enable --integration

disable-deployment-integration: ## Disable automatic deployments for integration
	cd bin/toggle-deployment && uv run toggle-deployment --disable --integration

enable-deployment-staging: ## Enable automatic deployments for staging
	cd bin/toggle-deployment && uv run toggle-deployment --enable --staging

disable-deployment-staging: ## Disable automatic deployments for staging
	cd bin/toggle-deployment && uv run toggle-deployment --disable --staging

enable-deployment-production: ## Enable automatic deployments for production
	cd bin/toggle-deployment && uv run toggle-deployment --enable --production

disable-deployment-production: ## Disable automatic deployments for production
	cd bin/toggle-deployment && uv run toggle-deployment --disable --production
