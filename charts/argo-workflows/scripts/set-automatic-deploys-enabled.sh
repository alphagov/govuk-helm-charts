#!/usr/bin/env bash
set -euo pipefail

BRANCH="update-image-tag/${REPO_NAME}/${ENVIRONMENT}/${IMAGE_TAG}/${AUTOMATIC_DEPLOYS_ENABLED}"
FILE="charts/argocd-apps/image-tags/${ENVIRONMENT}/${REPO_NAME}"
CHANGED=false

git config --global user.email "${GIT_NAME}@digital.cabinet-office.gov.uk"
git config --global user.name "${GIT_NAME}"

gh auth setup-git
gh repo clone alphagov/govuk-helm-charts -- --depth 1 --branch main

cd "govuk-helm-charts" || exit 1

commit() {
  git add "${FILE}"
  git commit -m "${1}"
  echo "${1}"
  CHANGED=true
}

update_image_tag() {
  if [[ -z "${IMAGE_TAG}" ]]; then
    yq -i '.image_tag = env(IMAGE_TAG)' "${FILE}"

    if [[ "$(git status --porcelain)" ]]; then
      commit "Update ${REPO_NAME} image tag to ${IMAGE_TAG} for ${ENVIRONMENT}"
    else
      echo "No change in image_tag"
    fi
  else
    echo "Received image_tag empty, skipping update"
  fi
}

set_automatic_deploys_enabled() {
  yq -i '.automatic_deploys_enabled = env(AUTOMATIC_DEPLOYS_ENABLED)' "${FILE}"

  if [[ "$(git status --porcelain)" ]]; then
    commit "Set ${REPO_NAME} automatic_deploys_enabled to ${AUTOMATIC_DEPLOYS_ENABLED} for ${ENVIRONMENT}"
  else
    echo "No change in automatic_deploys_enabled"
  fi
}

git config --global user.email "${GIT_NAME}@digital.cabinet-office.gov.uk"
git config --global user.name "${GIT_NAME}"

gh auth setup-git
gh repo clone alphagov/govuk-helm-charts -- --depth 1 --branch main
git checkout -b "${BRANCH}"

update_image_tag
set_automatic_deploys_enabled

if "${CHANGED}"; then
  git push -u origin "${BRANCH}"
  gh api repos/alphagov/govuk-helm-charts/merges -f head="${BRANCH}" -f base=main
  git push origin --delete "${BRANCH}"

  echo "Pushed changes to GitHub"
fi
