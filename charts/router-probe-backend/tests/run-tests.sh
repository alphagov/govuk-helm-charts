#!/usr/bin/env bash

set -euo pipefail

COMMANDS_NEEDED=(
  curl
  jq
  md5sum
  yq
)

HEADERS_REDACTED=(
  "authorization"
  "cookie"
  "proxy-authorization"
  "set-cookie"
  "x-amz-security-token"
  "x-forwarded-for"
)

for COMMAND in "${COMMANDS_NEEDED[@]}"; do
  if ! command -v "$COMMAND" >>/dev/null 2>&1; then
    echo "ERROR: Command $COMMAND must be installed and in the PATH"
    exit 1
  fi
done

TESTS_DIR="$(dirname "${BASH_SOURCE[0]}")"
CHART_DIR="$(realpath "${TESTS_DIR}/../")"

IMAGE=$(yq <"${CHART_DIR}/values.yaml" '.image.repository + ":" + .image.tag')
export IMAGE

function cleanup {
  echo
  echo "Shutting down docker compose stack"
  docker compose down -v
}

trap cleanup EXIT

echo "Starting docker compose stack"
if docker compose up --detach --wait --wait-timeout 15; then
  echo "Nginx container started"
else
  echo
  echo
  echo "----------------------------------------------------"
  echo "ERROR: Could not start nginx container. Logs follow:"
  echo "----------------------------------------------------"
  docker compose logs --since 1m
  exit 1
fi

TMPFILE=$(mktemp)

function expect {
  # Args:
  #   $1: HTTP Method
  #   $2: Resource path to curl
  #   $3: HTTP Status Code Expected
  # Stdout:
  #   Prints out the body returned
  local METHOD="$1"
  local RESOURCE="$2"
  local EXPECTED_STATUS="$3"
  local ACTUAL_STATUS

  >&2 echo -n "Testing ${METHOD} ${RESOURCE} returns ${EXPECTED_STATUS}... "
  # Note the headers set are to make it easy to test for redaction
  # and the random capitalisation is to ensure the redaction is being
  # performed ignoring case
  ACTUAL_STATUS=$(
    curl \
      --header "Authorization: foo" \
      --header "COOKIE: bar" \
      --header "Proxy-AuthoRIZATion: baz" \
      --header "Set-Cookie: qux" \
      --header "X-Amz-Security-ToKEN: quux" \
      --header "X-Forwarded-For: corge" \
      --header "X-Non-Redacted: grault" \
      --request "${METHOD}" \
      --silent \
      --write-out '%{http_code}\n' \
      --output "${TMPFILE}" "http://127.0.0.1:80${RESOURCE}" \
    | tail -n 1
  )

  if [ "$ACTUAL_STATUS" -eq "$EXPECTED_STATUS" ]; then
    >&2 echo "OK"
  else
    >&2 echo "ERROR"
    >&2 echo "  Status Code for $RESOURCE:"
    >&2 echo "    Expected: $EXPECTED_STATUS"
    >&2 echo "    Actual:   $ACTUAL_STATUS"
  fi

  cat "$TMPFILE"
}

echo "============================================="
echo "Executing Tests:"
echo "============================================="
{
  expect "GET" "/" "404"
  expect "GET" "/__probe__/ok" "200"
  expect "GET" "/__probe__/redirect" "301"
  expect "GET" "/__probe__/not-found" "404"
  expect "GET" "/__probe__/internal-server-error" "500"
  expect "GET" "/__probe__/get" "200"
  expect "POST" "/__probe__/get" "403"
  expect "GET" "/__probe__/post" "403"
  expect "POST" "/__probe__/post" "200"
} >> /dev/null

function expect_correct_header_redaction {
  # Args:
  #   $1: HTTP Method
  #   $2: 
  local METHOD=$1
  local RESOURCE=$2

  if ! RESPONSE=$(expect "$METHOD" "${RESOURCE}" "200"); then
    exit 1
  fi
  HEADERS=$(jq -r <<<"${RESPONSE}" '.requestHeaders')

  for HEADER in "${HEADERS_REDACTED[@]}"; do
    HEADER_VALUE=$(jq -r ".[\"$HEADER\"]" <<<"$HEADERS")
    >&2 echo -n "Testing Redaction of header $HEADER returned by $METHOD in $RESOURCE ... "
    if [ "$HEADER_VALUE" != "**REDACTED**" ]; then
      >&2 echo "ERROR"
      >&2 echo "  Header $HEADER was not redacted:"
      >&2 echo "    Expected: **REDACTED**"
      >&2 echo "    Actual:   $HEADER_VALUE"
      exit 1
    fi
    echo "OK"
  done

  >&2 echo -n "Testing to ensure other headers (X-Non-Redacted specifically) are not redacted by $METHOD in $RESOURCE ... "
  HEADER_VALUE=$(jq -r '.["x-non-redacted"]' <<<"$HEADERS")
  if [ "$HEADER_VALUE" != "grault" ]; then
    >&2 echo "ERROR"
    >&2 echo "  Value for X-Non-Redacted header:"
    >&2 echo "    Expected: grault"
    >&2 echo "    Actual:   $HEADER_VALUE"
    exit 1
  fi
  echo "OK"
}

expect_correct_header_redaction "GET" "/__probe__/headers/get"
expect "POST" "/__probe__/headers/get" "403" >>/dev/null
expect_correct_header_redaction "POST" "/__probe__/headers/post"
expect "GET" "/__probe__/headers/post" "403" >>/dev/null

echo "============================================="
