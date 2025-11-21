# Toggle CLI

The `toggle` CLI is a tool for enabling and disabling groups of workloads per environment in the `govuk-helm-charts` repository.

## Overview

The toggle CLI operates on local Helm values files (`charts/app-config/values-*.yaml`) and prepares changes for GitOps deployment. It does **not** directly interact with Kubernetes or AWS - instead, it modifies the configuration files, and you commit and push those changes through the normal Git workflow.

## Installation

From the root of the `govuk-helm-charts` repository:

### Using Make (Recommended)

```bash
# Build the binary
make toggle-build

# Install to /usr/local/bin (requires sudo)
make toggle-install
```

### Using Go Directly

```bash
go build -o toggle main.go
```

This will create a `toggle` binary in the current directory. You can move it to your `$PATH` if desired:

```bash
sudo mv toggle /usr/local/bin/
```

### Available Make Targets

Run `make help` to see all available targets. Toggle CLI targets include:
- `toggle-build` - Build the toggle binary
- `toggle-test` - Run all tests
- `toggle-test-verbose` - Run tests with verbose output
- `toggle-test-coverage` - Run tests with coverage
- `toggle-install` - Install to system path
- `toggle-clean` - Remove build artifacts

## Basic Usage

The toggle CLI has two main commands:

- `toggle enable` - Enable workloads (set `workers.enabled: true` or `appEnabled: true`)
- `toggle disable` - Disable workloads (set `workers.enabled: false` or `appEnabled: false`)

### Command Structure

```bash
toggle <enable|disable> --environment <env> --type <type> --workload <workload> [flags]
```

### Required Flags

- `--environment, -n` - Target environment: `integration`, `staging`, or `production`
- `--type, -t` - Type of workload: `workers` or `apps`
- `--workload, -w` - Workload category: `Publishing` or `Frontend`

### Optional Flags

- `--dry-run` - Show what would be changed without writing to disk
- `--yes, -y` - Skip interactive confirmation (useful for automation)

## How It Works

### App Categorisation

The toggle CLI uses the `apps.csv` file in the repository root as the source of truth for which apps belong to which workload category (Publishing, Frontend, etc.).

The CSV has the following structure:
- Column 1: App name
- Column 2: Category (Publishing, Frontend, n/a, etc.)
- Column 3: Worker indicator
- Column 4: CronJobs/CronTasks indicator

### Types

#### `--type workers`

When you use `--type workers`, the CLI modifies the `workers.enabled` field in the Helm values for each app in the specified workload:

```yaml
govukApplications:
  - name: publisher
    helmValues:
      workers:
        enabled: false  # Set by toggle disable
```

#### `--type apps`

When you use `--type apps`, the CLI modifies the `appEnabled` field in the Helm values:

```yaml
govukApplications:
  - name: publisher
    helmValues:
      appEnabled: false  # Set by toggle disable
```

## Examples

### Enable Integration Workers for Publishing

```bash
toggle enable --environment integration --type workers --workload Publishing
```

This will:
1. Load `apps.csv` to find all Publishing apps
2. For each app, set `workers.enabled: true` in `charts/app-config/values-integration.yaml`
3. Show you a summary of changes
4. Ask for confirmation (unless `--yes` is used)
5. Write the changes to the file

### Disable Staging Apps for Frontend (Dry Run)

```bash
toggle disable --environment staging --type apps --workload Frontend --dry-run
```

This will:
1. Load `apps.csv` to find all Frontend apps
2. For each app, calculate what changes would be made (`appEnabled: false`)
3. Display the changes
4. Exit **without** writing to disk

### Enable Production Workers (with Auto-Confirm)

```bash
toggle enable --environment production --type workers --workload Publishing --yes
```

**⚠️ Warning:** This will modify production configuration without interactive confirmation. You'll still see a production warning, but it won't ask for confirmation.

## Safety Features

### Production Guardrail

When targeting the `production` environment, the CLI will:

1. Display a prominent warning
2. Clearly state that you're modifying production
3. Ask for explicit confirmation (unless `--yes` is used)

Example output:

```
⚠️  WARNING: PRODUCTION ENVIRONMENT
═══════════════════════════════════════════════
You are about to make changes to PRODUCTION.
These changes will affect live services.

Are you absolutely sure you want to modify PRODUCTION? [y/N]:
```

### Dirty Working Tree Check

Before making changes, the CLI checks if your Git working tree has uncommitted changes. If it does, the CLI will refuse to run (unless `--dry-run` is used).

This ensures you don't accidentally mix changes from different operations.

To bypass this, commit or stash your changes first:

```bash
git stash
toggle enable --environment integration --type workers --workload Publishing
git stash pop
```

### Dry Run Mode

Always use `--dry-run` first to see what would change:

```bash
toggle disable --environment staging --type apps --workload Frontend --dry-run
```

This shows you:
- Which apps will be affected
- Which files will be modified
- What the old and new values will be

No files are written in dry-run mode.

## Workflow Example

Here's a complete workflow for disabling Frontend apps in staging:

```bash
# 1. Check the current state
git status  # Ensure clean working tree

# 2. Preview the changes
toggle disable --environment staging --type apps --workload Frontend --dry-run

# 3. Apply the changes
toggle disable --environment staging --type apps --workload Frontend

# 4. Review the changes
git diff

# 5. Commit the changes
git add charts/app-config/values-staging.yaml
git commit -m "Disable Frontend apps in staging for maintenance"

# 6. Create a PR
gh pr create --title "Disable Frontend apps in staging" \
             --body "Disabling Frontend apps for scheduled maintenance."

# 7. Once approved and merged, GitOps (ArgoCD) will apply the changes
```

## Supported Workloads

Based on `apps.csv`, the following workloads are currently supported:

- **Publishing** - Apps related to content publishing (34 apps)
  - Examples: `publisher`, `whitehall-admin`, `content-tagger`, `signon`, etc.

- **Frontend** - Apps serving public-facing content (24 apps)
  - Examples: `frontend`, `government-frontend`, `collections`, `finder-frontend`, etc.

To see which apps are in each workload, check the `apps.csv` file.

## Limitations and Considerations

1. **No automatic Git operations** - The CLI only modifies files. You must commit and push changes yourself.

2. **App must exist in values file** - If an app is listed in `apps.csv` but doesn't exist in the values file, you'll see a warning, but the CLI will continue processing other apps.

3. **CSV is source of truth** - If an app isn't in `apps.csv` or is categorized incorrectly, it won't be affected by toggle commands. Update the CSV if needed.

4. **Workers vs Apps** - Make sure you understand the difference:
   - `workers` affects background job processing (`workers.enabled`)
   - `apps` affects the main application (`appEnabled`)

5. **Multiple environments** - If you need to make the same change across multiple environments, run the command for each environment separately.

## Troubleshooting

### "working tree is dirty"

**Problem:** You have uncommitted changes.

**Solution:** Commit or stash your changes, or use `--dry-run` to preview.

```bash
git stash
# run toggle command
git stash pop
```

### "no apps found for workload"

**Problem:** The workload name doesn't match any entries in `apps.csv`.

**Solution:** Check `apps.csv` for the correct workload name. Note that it's case-sensitive (`Publishing`, not `publishing`).

### "app X not found in values file"

**Problem:** An app is in `apps.csv` but not in the environment's values file.

**Solution:** This is usually a warning, not an error. The CLI will continue with other apps. Check if the app name in the CSV matches the values file, or if the app simply doesn't exist in that environment.

### Changes aren't taking effect in the cluster

**Problem:** You've committed and pushed changes, but the cluster hasn't updated.

**Solution:** This CLI only modifies configuration files. The actual deployment is handled by GitOps (ArgoCD). Check:
1. Did your PR get merged?
2. Check ArgoCD to see if it's syncing the changes
3. Look for ArgoCD sync errors

## Advanced Usage

### Scripting with --yes

For automation or scripting, use `--yes` to skip confirmation:

```bash
#!/bin/bash
toggle disable --environment integration --type workers --workload Publishing --yes
git add -A
git commit -m "Automated: Disable Publishing workers in integration"
git push
```

### Checking Changes Before Commit

Always review the diff before committing:

```bash
toggle enable --environment staging --type apps --workload Frontend
git diff --color-words charts/app-config/values-staging.yaml
```

## Getting Help

```bash
# General help
toggle --help

# Help for specific command
toggle enable --help
toggle disable --help
```

## Contributing

If you find bugs or want to add features:

1. Create an issue in the `govuk-helm-charts` repository
2. Submit a PR with tests
3. Update this documentation

## Related Documentation

- [GOV.UK Helm Charts README](../README.md)
- [App Config Chart](../charts/app-config/README.md)
- ArgoCD GitOps Workflow Documentation
