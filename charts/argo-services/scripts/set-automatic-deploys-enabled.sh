#!/usr/bin/env bash
set -euo pipefail

BRANCH="update-image-tag/${REPO_NAME}/${ENVIRONMENT}/${AUTOMATIC_DEPLOYS_ENABLED}"
FILE="charts/app-config/image-tags/${ENVIRONMENT}/${REPO_NAME}"
CHANGED=false

git config --global user.email "${GIT_NAME}@digital.cabinet-office.gov.uk"
git config --global user.name "${GIT_NAME}"

gh auth setup-git
gh repo clone alphagov/govuk-helm-charts -- --depth 1 --branch main

cd "govuk-helm-charts" || exit 1

git checkout -b "${BRANCH}"

yq -i '.automatic_deploys_enabled = env(AUTOMATIC_DEPLOYS_ENABLED)' "${FILE}"

if [[ "$(git status --porcelain)" ]]; then
  git add "${FILE}"
  git commit -m "Set ${REPO_NAME} automatic_deploys_enabled to ${AUTOMATIC_DEPLOYS_ENABLED} for ${ENVIRONMENT}"
  CHANGED=true
else
  echo "No change in automatic_deploys_enabled"
fi

if [[ "${CHANGED}" = true ]]; then
  git push -u origin "${BRANCH}"
  gh api repos/alphagov/govuk-helm-charts/merges -f head="${BRANCH}" -f base=main
  git push origin --delete "${BRANCH}"

  echo "Pushed changes to GitHub"
fi
