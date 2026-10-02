SHELL=bash
.PHONY: check-yamllint lint lint-helm check help enable-deployment-integration disable-deployment-integration enable-deployment-staging disable-deployment-staging enable-deployment-production disable-deployment-production

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

lint-helm: ## Render every Argo CD app and helm lint this repo's charts
	bin/render-argo-apps.py --lint --skip-remote-charts

check: lint ## Alias for lint target
