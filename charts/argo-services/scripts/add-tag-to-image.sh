#!/usr/bin/env bash
set -euo pipefail

# Add pull-through cache prefix
REPOSITORY_NAME="github/alphagov/govuk/${REPOSITORY_NAME}"

# Check if image is already tagged
TAG_EXISTS=$(aws ecr describe-images \
  --registry-id "${AWS_ACCOUNT}" \
  --repository-name "${REPOSITORY_NAME}" \
  --image-ids imageTag="${REFERENCE_TAG}" \
  --query "imageDetails[].imageTags | [] | contains(@, '${NEW_TAG}')")

if [[ "${TAG_EXISTS}" = true ]]; then
  echo "Image tagged ${REFERENCE_TAG} already has ${NEW_TAG} tag."
  exit 0
fi

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
