#!/usr/bin/env bash
set -euo pipefail

BRANCH="update-image-tag/${REPO_NAME}/${ENVIRONMENT}/${IMAGE_TAG}"
FILE="charts/argocd-apps/image-tags/${ENVIRONMENT}/${REPO_NAME}"
LATEST_GIT_SHA=$(git ls-remote "https://github.com/alphagov/${REPO_NAME}" HEAD | cut -f 1)

git config --global user.email "${GIT_NAME}@digital.cabinet-office.gov.uk"
git config --global user.name "${GIT_NAME}"

gh auth setup-git
gh repo clone alphagov/govuk-helm-charts -- --depth 1 --branch main

cd "govuk-helm-charts" || exit 1

# Exit successfully if image tag already set
if [[ $(<"${FILE}") = "${IMAGE_TAG}" ]]; then
  echo "Image tag already set as ${IMAGE_TAG}"
# Relies on the assumption the IMAGE_TAG is a commit SHA
elif [[ "${LATEST_GIT_SHA}" = "${IMAGE_TAG}" ]] || [[ "${MANUAL_DEPLOY}" = true ]]; then
  git checkout -b "${BRANCH}"

  echo "${IMAGE_TAG}" >"${FILE}"

  git add "${FILE}"
  git commit -m "Update ${REPO_NAME} image tag to ${IMAGE_TAG} for ${ENVIRONMENT}"

  git push -u origin "${BRANCH}"
  gh api repos/alphagov/govuk-helm-charts/merges -f head="${BRANCH}" -f base=main
  git push origin --delete "${BRANCH}"

  echo "Done!"
else
  echo "Image tag not updated for ${ENVIRONMENT}: image tag not the latest commit on main."
fi
