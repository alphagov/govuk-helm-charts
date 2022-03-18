set -eu && \
export ERROR_PAGES=(400 401 403 404 405 406 410 422 429 500 502 503 504) && \
mkdir /error_pages && \
for page in "${ERROR_PAGES[@]}"; do \
  echo "${page}"
  curl --fail "http://static/templates/${page}.html.erb" > /error_pages/${page}.html; \
done; \
aws s3 sync "/error_pages/" "s3://govuk-app-assets-${GOVUK_ENVIRONMENT}/error_pages/"
