# Toggle CLI

A CLI tool for enabling and disabling GOV.UK workloads in Helm charts.

## Quick Start

### Build

Using Make (recommended):
```bash
make toggle-build
```

Or using Go directly:
```bash
go build -o toggle main.go
```

### Usage

```bash
# Enable integration workers for Publishing apps
./toggle enable --environment integration --type workers --workload Publishing

# Disable staging apps for Frontend with dry-run
./toggle disable --environment staging --type apps --workload Frontend --dry-run

# Enable with auto-confirmation (no prompts)
./toggle enable --environment integration --type apps --workload Publishing --yes
```

## Commands

- `toggle enable` - Enable workers or apps
- `toggle disable` - Disable workers or apps

## Flags

**Required:**

- `--environment, -n` - Environment: `integration`, `staging`, or `production`
- `--type, -t` - Type: `workers` or `apps`
- `--workload, -w` - Workload: `Publishing`, `Frontend`, etc.

**Optional:**

- `--dry-run` - Preview changes without writing
- `--yes, -y` - Skip confirmation prompts

## How It Works

1. **Reads** `apps.csv` to determine which apps belong to each workload
2. **Modifies** the appropriate values file (`charts/app-config/values-<environment>.yaml`)
3. **Sets** either `workers.enabled` or `appEnabled` based on `--type`
4. **Leaves** changes in your working tree for you to commit

## Documentation

See [docs/toggle-cli.md](docs/toggle-cli.md) for comprehensive documentation including:

- Detailed usage examples
- Safety features and guardrails
- Complete workflow examples
- Troubleshooting guide

## Testing

Using Make (recommended):
```bash
# Run all tests
make toggle-test

# Run tests with verbose output
make toggle-test-verbose

# Run tests with coverage
make toggle-test-coverage
```

Or using Go directly:
```bash
# Run all tests
go test ./...

# Run tests with coverage
go test ./... -cover

# Run specific package tests
go test ./internal/config/ -v
go test ./internal/helm/ -v
```

## Makefile Targets

```bash
# Show all available targets
make help

# Toggle CLI targets:
make toggle-build              # Build the binary
make toggle-test               # Run tests
make toggle-test-verbose       # Run tests with verbose output
make toggle-test-coverage      # Run tests with coverage
make toggle-install            # Install to /usr/local/bin
make toggle-clean              # Remove build artifacts
```

## Development

Project structure:

```
.
├── main.go                      # Entry point
├── cmd/                         # Cobra commands
│   ├── root.go                  # Root command
│   ├── enable.go                # Enable command
│   └── disable.go               # Disable command
├── internal/
│   ├── config/                  # CSV parsing and app catalog
│   │   ├── csv.go
│   │   └── csv_test.go
│   ├── helm/                    # YAML manipulation
│   │   ├── values.go
│   │   └── values_test.go
│   ├── git/                     # Git utilities
│   │   └── git.go
│   └── ui/                      # User interface helpers
│       └── ui.go
└── docs/
    └── toggle-cli.md            # Full documentation
```

## Example Workflow

```bash
# 1. Build the CLI
make toggle-build

# 2. Preview changes
./toggle disable --environment staging --type apps --workload Frontend --dry-run

# 3. Apply changes
./toggle disable --environment staging --type apps --workload Frontend

# 4. Review and commit
git diff
git add charts/app-config/values-staging.yaml
git commit -m "♻️Disable Frontend apps in staging"

# 5. Create PR
gh pr create --title "Disable Frontend apps in staging" \
             --body "Disabling for scheduled maintenance"
```

## Requirements

- Go 1.25 or later
- Git
- Clean working tree (no uncommitted changes)
