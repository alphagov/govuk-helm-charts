# Toggle Deployment

Tool for toggling `automatic_deploys_enabled` across all apps in an environment.

## Usage

From the repository root:

```bash
make disable-deployment-integration
make enable-deployment-staging
```

Or directly:

```bash
cd bin/toggle-deployment
uv run toggle-deployment --disable --integration --dry-run
```

## How it works

The script updates `automatic_deploys_enabled` in all image-tag files under `charts/app-config/image-tags/<environment>/`. It preserves existing values for `image_tag` and `promote_deployment`, and refuses to run if the working tree is dirty (use `--force` to override).

## Setup

```bash
cd bin/toggle-deployment
uv sync
```

## Testing

```bash
uv run pytest
uv run ruff check .
```
