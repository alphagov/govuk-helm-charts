#!/usr/bin/env bash
set -euo pipefail

# Get existing image manifest from AWS ECR
MANIFEST=$(aws ecr batch-get-image \
  --registry-id "${AWS_ACCOUNT}" \
  --repository-name "${REPOSITORY_NAME}" \
  --image-ids imageTag="${REFERENCE_TAG}" \
  --query 'images[].imageManifest' \
  --output text)

# Add tag to image
aws ecr put-image \
  --registry-id "${AWS_ACCOUNT}" \
  --repository-name "${REPOSITORY_NAME}" \
  --image-tag "${NEW_TAG}" \
  --image-manifest "${MANIFEST}"
