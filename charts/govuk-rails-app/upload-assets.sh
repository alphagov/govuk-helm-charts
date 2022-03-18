#!/bin/sh
set -eu

# Fail fast if the source path doesn't exist in the image.
if ! [ -d "${ASSETS_SOURCE_PATH}" ]; then
  echo Source path "${ASSETS_SOURCE_PATH}" does not exist. Aborting. >&2
  exit 1
fi

# TODO: remove this horrible hack of installing awscli inside the container by
# building it (or a smaller equivalent like s5cmd) into the base image. Better
# still: have the build process emit the assets and just copy them to the
# serving bucket here, without involving the app image.
apt-get update
apt-get install -y awscli

aws s3 sync "${ASSETS_SOURCE_PATH}" \
  "s3://govuk-app-assets-${GOVUK_ENVIRONMENT}/assets/${ASSETS_DEST_DIR}/"
