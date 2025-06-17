.PHONY: install-yamllint lint check help

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install-yamllint: ## Install yamllint via package manager if not already installed
	@if command -v yamllint >/dev/null 2>&1; then \
		echo "yamllint is already installed ($(shell yamllint --version))"; \
	elif command -v brew >/dev/null 2>&1; then \
		echo "Installing yamllint via brew..."; \
		brew install yamllint; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "Installing yamllint via apt..."; \
		sudo apt-get update && sudo apt-get install -y yamllint; \
	else \
		echo "Error: No supported package manager found (brew or apt)."; \
		exit 1; \
	fi

lint: install-yamllint ## Run yamllint on all YAML files
	@echo "Running yamllint..."
	yamllint -f github .

check: lint ## Alias for lint target
