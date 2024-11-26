#!/usr/bin/env bash
set -euo pipefail

BRANCH="update-image-tag/${REPO_NAME}/${ENVIRONMENT}/${IMAGE_TAG}"
FILE="charts/app-config/image-tags/${ENVIRONMENT}/${REPO_NAME}"

git config --global user.email "${GIT_NAME}@digital.cabinet-office.gov.uk"
git config --global user.name "${GIT_NAME}"

gh auth setup-git
cd /tmp
gh repo clone alphagov/govuk-helm-charts -- --depth 1 --branch main

cd "govuk-helm-charts" || exit 1

current_image_tag="$(yq '.image_tag' "${FILE}")"

# Ignore if image tag already set
if [[ "${current_image_tag}" = "${IMAGE_TAG}" ]]; then
  echo "Image tag already set as ${IMAGE_TAG}"
  exit 0
fi

# Delete branch at origin if already exists
if git ls-remote --heads origin "${BRANCH}" | grep -q "${BRANCH}"; then
    echo "Deleting existing branch ${BRANCH} at origin"
    git push origin --delete "${BRANCH}"
fi

git checkout -b "${BRANCH}"

yq -i '.image_tag = env(IMAGE_TAG)' "${FILE}"
yq -i '.promote_deployment = env(PROMOTE_DEPLOYMENT)' "${FILE}"

git add "${FILE}"
git commit -m "Update ${REPO_NAME} image tag to ${IMAGE_TAG} for ${ENVIRONMENT}"

git push -u origin "${BRANCH}"
gh api repos/alphagov/govuk-helm-charts/merges -f head="${BRANCH}" -f base=main
git push origin --delete "${BRANCH}"

echo "Pushed changes to GitHub"
