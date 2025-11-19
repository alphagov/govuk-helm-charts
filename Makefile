.PHONY: check-yamllint lint check help toggle-build toggle-test toggle-test-verbose toggle-clean toggle-install

# Toggle CLI binary
TOGGLE_BINARY=toggle
INSTALL_PATH=/usr/local/bin

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

lint: check-yamllint ## Run yamllint on all YAML files
	@echo "Running yamllint..."
	yamllint -f github .

check: lint ## Alias for lint target

# Toggle CLI targets
toggle-build: ## Build the toggle CLI binary
	@echo "Building toggle CLI..."
	go build -o $(TOGGLE_BINARY) main.go
	@echo "✓ Built: ./$(TOGGLE_BINARY)"

toggle-test: ## Run all Go tests for toggle CLI
	@echo "Running Go tests..."
	go test ./...

toggle-test-verbose: ## Run Go tests with verbose output
	@echo "Running Go tests (verbose)..."
	go test -v ./...

toggle-test-coverage: ## Run Go tests with coverage
	@echo "Running Go tests with coverage..."
	go test -cover ./...

toggle-clean: ## Remove toggle binary and test artifacts
	@echo "Cleaning toggle artifacts..."
	@rm -f $(TOGGLE_BINARY) coverage.out coverage.html
	go clean
	@echo "✓ Clean complete"

toggle-install: toggle-build ## Install toggle binary to system path
	@echo "Installing $(TOGGLE_BINARY) to $(INSTALL_PATH)..."
	@if [ -w $(INSTALL_PATH) ]; then \
		cp $(TOGGLE_BINARY) $(INSTALL_PATH)/$(TOGGLE_BINARY); \
		echo "✓ Installed to $(INSTALL_PATH)/$(TOGGLE_BINARY)"; \
	else \
		echo "Need sudo to install to $(INSTALL_PATH)"; \
		sudo cp $(TOGGLE_BINARY) $(INSTALL_PATH)/$(TOGGLE_BINARY); \
		echo "✓ Installed to $(INSTALL_PATH)/$(TOGGLE_BINARY)"; \
	fi
