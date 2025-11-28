# App Management

A Python script to automatically enable/disable various app components by modifying an environment's values file.

The scripts uses yq to make changes to the values file.
Comments, YAML anchors and general layout are preserved by yq when it rewrites the values file.

## Requirements

* `uv`
* `yq` version 4 or higher

## Usage

This script requires a CSV export of the 'App categories for the migration work' spreadsheet.
This sheet is available in Google Drive.

Each script updates the provided YAML file in-place.

See `./manage-yq.py --help` for a list of all arguments.

Examples:

```sh
# disable big 20 publishing app deployments in production
./bin/manage-apps/manage-yq.py \
  --set big20 \
  --phase publishing \
  --action disable \
  --target app \
  --values charts/app-config/values-production.yaml \
  --manifest /path/to/spreadsheet/export.csv

# enable big 20 frontend cron jobs in staging
./bin/manage-apps/manage-yq.py \
  --set big20 \
  --phase frontend \
  --action enable \
  --target cron \
  --values charts/app-config/values-staging.yaml \
  --manifest /path/to/spreadsheet/export.csv

# enable all small 6 workers in production
./bin/manage-apps/manage-yq.py \
  --set small6 \
  --phase all \
  --action enable \
  --target worker \
  --values charts/app-config/values-production.yaml \
  --manifest /path/to/spreadsheet/export.csv
```
