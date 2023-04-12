#!/usr/bin/env bash
set -euo pipefail

# Fetch the YAML configuration
CONFIG_URL="https://raw.githubusercontent.com/alphagov/govuk-helm-charts/main/charts/app-config/image-tags/${ENVIRONMENT}/${REPO_NAME}"
CONFIG_CONTENT=$(curl -Ls "${CONFIG_URL}")

# Extract the values of automatic_deploys_enabled and promote_deployment
automatic_deploys_enabled=$(echo "${CONFIG_CONTENT}" | yq '.automatic_deploys_enabled // true' -)
promote_deployment=$(echo "${CONFIG_CONTENT}" | yq '.promote_deployment' -)

# Check if both values are true
if [ "${automatic_deploys_enabled,,}" == "true" ] && [ "${promote_deployment,,}" == "true" ]; then
  echo "true"
else
  echo "false"
fi
