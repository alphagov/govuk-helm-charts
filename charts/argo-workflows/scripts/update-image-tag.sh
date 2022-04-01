#!/usr/bin/env bash
set -euo pipefail

apt-get update && apt-get install -y git curl

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

apt-get update && apt-get install -y gh

BRANCH="update-image-tag/${APPLICATION}/${ENVIRONMENT}/${IMAGE_TAG}"
FILE="charts/argocd-apps/image-tags/${ENVIRONMENT}/${REPO_NAME}"
LATEST_GIT_SHA=$("git ls-remote https://github.com/alphagov/${REPO_NAME} HEAD | cut -f 1")

git config --global user.email "${GIT_NAME}@digital.cabinet-office.gov.uk"
git config --global user.name "${GIT_NAME}"

gh auth setup-git
gh repo clone alphagov/govuk-helm-charts -- --depth 1 --branch main

cd "govuk-helm-charts" || exit 1

# Relies on the assumption the IMAGE_TAG is a commit SHA
if [ "${LATEST_GIT_SHA}" = "${IMAGE_TAG}" ]; then
  git checkout -b "${BRANCH}"

  echo "${IMAGE_TAG}" > "${FILE}"

  git add "${FILE}"
  git commit -m "Deploy ${APPLICATION}:${IMAGE_TAG} to ${ENVIRONMENT}"

  git push -u origin "${BRANCH}"
  gh api repos/alphagov/govuk-helm-charts/merges -f head="${BRANCH}" -f base=main
  git push origin --delete "${BRANCH}"

  echo "Done!"
else
  echo "Image tag not updated for ${ENVIRONMENT}: image tag not the latest commit on main."
  exit 1
fi
