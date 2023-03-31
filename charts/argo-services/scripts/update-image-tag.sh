#!/usr/bin/env bash
set -euo pipefail

BRANCH="update-image-tag/${REPO_NAME}/${ENVIRONMENT}/${IMAGE_TAG}"
FILE="charts/app-config/image-tags/${ENVIRONMENT}/${REPO_NAME}"
CHANGED=false

change_image_tag() {
  git checkout -b "${BRANCH}"

  yq -i '.image_tag = env(IMAGE_TAG)' "${FILE}"
  yq -i '.promote_deployment = env(PROMOTE_DEPLOYMENT)' "${FILE}"

  git add "${FILE}"
  git commit -m "Update ${REPO_NAME} image tag to ${IMAGE_TAG} for ${ENVIRONMENT}"

  CHANGED=true
}

git config --global user.email "${GIT_NAME}@digital.cabinet-office.gov.uk"
git config --global user.name "${GIT_NAME}"

gh auth setup-git
gh repo clone alphagov/govuk-helm-charts -- --depth 1 --branch main

cd "govuk-helm-charts" || exit 1

current_image_tag="$(yq '.image_tag' "${FILE}")"

# Ignore if image tag already set
if [[ "${current_image_tag}" = "${IMAGE_TAG}" ]]; then
  echo "Image tag already set as ${IMAGE_TAG}"
else
  change_image_tag
fi

if [[ "${CHANGED}" = true ]]; then
  git push -u origin "${BRANCH}"
  gh api repos/alphagov/govuk-helm-charts/merges -f head="${BRANCH}" -f base=main
  git push origin --delete "${BRANCH}"

  echo "Pushed changes to GitHub"
fi
