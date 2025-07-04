.PHONY: check-yamllint lint check help

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-yamllint: ## Check if yamllint is installed
	@if command -v yamllint >/dev/null 2>&1; then \
		echo "yamllint is already installed ($(shell yamllint --version))"; \
	else \
		echo "Please install yamllint before running this Makefile."; \
		exit 1; \
	fi

yamllint: check-yamllint ## Run yamllint on all YAML files
	@echo "Running yamllint..."
	yamllint -f github .

lint: check-yamllint kubeconform ## Run yamllint on all YAML files

check: lint ## Alias for lint target

kubeconform: ## Run kubeconform validation on rendered charts
	@echo "Rendering charts..."
	./govuk-app-render.sh
	@echo "Running kubeconform..."
	docker run --rm -v "$(PWD)/output:/workspace" ghcr.io/yannh/kubeconform:latest-alpine \
		-kubernetes-version 1.31.6 \
		-schema-location default \
		-schema-location "https://alphagov.github.io/govuk-crd-library/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
		-ignore-filename-pattern ".*/Chart.yaml" \
		-summary \
		-strict \
		/workspace/rendered-charts
