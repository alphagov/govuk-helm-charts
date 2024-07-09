#!/bin/bash
set -euo pipefail
export LC_ALL=C.UTF-8  # Prevent i18n from affecting command outputs (e.g. `type`).

usage () {
  cat >&2 <<EOF

$self is a tool for creating and restoring Elasticsearch/Opensearch snapshots
in order to copy indices between clusters/environments.

Usage examples:

GOVUK_ENVIRONMENT=production $self create_and_clean_up
GOVUK_ENVIRONMENT=staging SNAPSHOT_REPO=govuk-integration) $self restore_latest

export ES_URL=https://elasticsearch.example.com SNAPSHOT_REPO=myrepo
$self list
SNAPSHOT_NAME=foo $self create
SNAPSHOT_NAME=foo $self restore
SNAPSHOT_NAME=foo $self delete

Either GOVUK_ENVIRONMENT, or both ES_URL and SNAPSHOT_REPO must be provided.

EOF
  exit 64  # EX_USAGE; see sysexits(3).
}

create () {
  : "${SNAPSHOT_NAME:?required}"
  local result
  result=$($curl -XPUT "$ES_URL/_snapshot/$SNAPSHOT_REPO/$SNAPSHOT_NAME?wait_for_completion=true")
  echo "$result" | jq
  echo "$result" | jq -r .snapshot.state | grep -Fx "SUCCESS"
}

delete () {
  local result
  result=$($curl -XDELETE "$ES_URL/_snapshot/$SNAPSHOT_REPO/$SNAPSHOT_NAME")
  echo "$result" | jq -e .acknowledged >/dev/null
}

# List all snapshots in ascending date order (as returned by ES).
list () {
  $curl "$ES_URL/_snapshot/$SNAPSHOT_REPO/_all" | jq -e '.snapshots'
}

# Enable or disable automatic index creation on insert.
# usage: set_auto_create_index true|false
set_auto_create_index () {
  # TODO: use curl --json once available (requires curl >= 7.82).
  $curl -XPUT "$ES_URL/_cluster/settings" -H 'Content-Type: application/json' \
    -d '{ "persistent": { "action.auto_create_index": "'"$1"'" } }' >&2
}

snapshot_valid () {
  : "${SNAPSHOT_NAME:?required}"
  list | jq -r '. | map(select(.state == "SUCCESS"))[].snapshot' \
    | grep -Fx "$SNAPSHOT_NAME"
}

restore () {
  snapshot_valid

  set_auto_create_index false
  trap 'set_auto_create_index true' EXIT HUP INT TERM

  $curl -XDELETE "$ES_URL/*,-.*" >&2  # Delete all except system indices.
  local result
  result=$(
    # TODO: use curl --json once available.
    $curl -XPOST -H'Content-Type: application/json' -d'{"indices": "*,-.*"}' \
      "$ES_URL/_snapshot/$SNAPSHOT_REPO/$SNAPSHOT_NAME/_restore"
  )

  echo "$result" | jq -e .accepted >/dev/null
}

latest_successful () {
  list | jq -r '. | map(select(.state == "SUCCESS"))[-1].snapshot'
}

restore_latest () {
  SNAPSHOT_NAME=$(latest_successful) restore
}

# List all completed snapshots except for the n most recent.
snapshots_to_delete () {
  list | \
    jq -r '. | map(select(.state == "SUCCESS"))[:-'"$SNAPSHOTS_TO_KEEP"'][].snapshot'
}

cleanup () {
  for snap in $(snapshots_to_delete); do
    SNAPSHOT_NAME=$snap delete || true  # Continue on error.
  done
}

create_and_clean_up () {
  SNAPSHOT_NAME=$(date +%Y-%m-%d%H:%M:%S)-chat-opensearch create
  SNAPSHOT_REPO="govuk-$GOVUK_ENVIRONMENT" cleanup
}


self=$(basename "$0")
subcommand=${1:-}
[[ $(type -t "$subcommand") == function ]] || usage

# We need a version of jq that understands negative slice offsets and -e (--exit-status).
if ! echo '[true]' | jq -e '.[-1]' >/dev/null 2>&1; then
  echo >&2 "$self: compatible version of jq not found; please install jq >=1.5"
  exit 69  # EX_UNAVAILABLE
fi

if [[ -n "$GOVUK_ENVIRONMENT" ]]; then
  : "${ES_URL:=https://chat-opensearch.$GOVUK_ENVIRONMENT.govuk-internal.digital}"
  : "${SNAPSHOT_REPO:=govuk-$GOVUK_ENVIRONMENT}"
fi

: "${ES_URL:?required}"
: "${SNAPSHOT_REPO:?required}"
: "${SNAPSHOTS_TO_KEEP:=1}"
: "${REQUEST_DEADLINE_SECONDS:=900}"  # Keep this > ES's 30s timeout to preserve error messages.
readonly GOVUK_ENVIRONMENT ES_URL SNAPSHOTS_TO_KEEP REQUEST_DEADLINE_SECONDS

curl="curl -Ssm$REQUEST_DEADLINE_SECONDS --fail-with-body"

[[ "${VERBOSE:-0}" -ge 1 ]] && set -x
$subcommand
