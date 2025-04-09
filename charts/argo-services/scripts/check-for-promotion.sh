#!/usr/bin/env bash
set -euo pipefail

# Ensure the image tag starts with a v
if [ "${IMAGE_TAG:0:1}" != "v" ]; then
  echo "false"
  exit 0
fi

# Fetch the YAML configuration
CONFIG_URL="/repos/alphagov/govuk-helm-charts/contents/charts/app-config/image-tags/${ENVIRONMENT}/${REPO_NAME}?ref=main"
CONFIG_CONTENT=$(gh api --cache 0 "${CONFIG_URL}" -q '.content' | base64 --decode)

# Extract the values of automatic_deploys_enabled and promote_deployment
automatic_deploys_enabled=$(echo "${CONFIG_CONTENT}" | yq '.automatic_deploys_enabled' -)
promote_deployment=$(echo "${CONFIG_CONTENT}" | yq '.promote_deployment' -)

# Check if both values are true
if [ "${automatic_deploys_enabled,,}" == "true" ] && [ "${promote_deployment,,}" == "true" ]; then
  echo "true"
else
  echo "false"
fi
