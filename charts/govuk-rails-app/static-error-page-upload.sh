#!/bin/sh
set -eu

ERROR_PAGES="400 401 403 404 405 406 410 422 429 500 502 503 504"
OUTPUT_PATH=/var/error_pages

mkdir -p "${OUTPUT_PATH}"
for page in $ERROR_PAGES; do
  echo "${page}"
  curl --fail --output "${OUTPUT_PATH}/${page}.html" "http://static/templates/${page}.html.erb"
done

aws s3 sync "${OUTPUT_PATH}/" "s3://govuk-app-assets-${GOVUK_ENVIRONMENT}/error_pages/"
