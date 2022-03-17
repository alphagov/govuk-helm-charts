#!/bin/bash
apt-get update && apt-get install -y git

git config --global user.email "${GIT_EMAIL}"
git config --global user.name govuk-ci

BRANCH="update-image-tag/${APPLICATION}/${ENVIRONMENT}/${IMAGE_TAG}"
FILE="charts/argocd-apps/image-tags/${ENVIRONMENT}/${APPLICATION}"

cd "govuk-helm-charts" || exit 1

LATEST_GIT_SHA=$(git rev-parse main)

if [ "${LATEST_GIT_SHA}" == "${IMAGE_TAG}" ]; then
  echo "Modifying Helm Charts repo..."

  git checkout -b "${BRANCH}"

  echo "${IMAGE_TAG}" >"{$FILE}"

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
