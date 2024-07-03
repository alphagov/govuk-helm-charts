#!/bin/bash
set -eux

ERROR_PAGES='400 401 403 404 405 406 410 422 429 500 502 503 504'
ERROR_PAGES_COMMA_SEPARATED=${ERROR_PAGES// /,}
OUTPUT_PATH=/tmp/output

mkdir -p "${OUTPUT_PATH}"
cd "${OUTPUT_PATH}"
curl --fail-early -fo '#1.html' "${SERVICE}/templates/{${ERROR_PAGES_COMMA_SEPARATED}}.html.erb"
touch healthcheck.html
eval ls "{$ERROR_PAGES_COMMA_SEPARATED}.html" || (echo Failed to download one or more files.; exit 1)
aws s3 sync . "s3://govuk-app-assets-${GOVUK_ENVIRONMENT}/error_pages/"
