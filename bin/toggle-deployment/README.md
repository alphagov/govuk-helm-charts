# Toggle Deployment

CLI tool to toggle `automatic_deploys_enabled` for GOV.UK Helm charts.

## Installation

```bash
cd bin/toggle-deployment
uv sync
```

## Usage

```bash
# Enable automatic deployments for integration
uv run toggle-deployment --enable --integration

# Disable automatic deployments for staging
uv run toggle-deployment --disable --staging

# Dry-run mode
uv run toggle-deployment --disable --production --dry-run
```

## Development

```bash
# Install dependencies
uv sync

# Run tests
uv run pytest

# Lint code
uv run ruff check .
```
