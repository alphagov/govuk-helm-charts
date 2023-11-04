#!/bin/bash
set -euo pipefail

source_dir=$(dirname "${BASH_SOURCE[0]}")
. "$source_dir/lib.sh"

export PGUSER=$DB_USER
export PGPASSWORD=$DB_PASSWORD
export PGHOST=$DB_HOST
export PGDATABASE=$DB_DATABASE
readonly PGUSER PGPASSWORD PGHOST PGDATABASE

backup () {
  local s3_path
  s3_path="$PGHOST/$(date -u +%Y-%m-%dT%H%M%SZ)-$PGDATABASE.gz"
  pg_dump -Fc | progress | aws s3 cp - "$BUCKET/$s3_path"
}

dump_is_readable () {
  (aws s3 cp "$s3_url" - 2>/dev/null || true) | head | file - | tee /dev/fd/2 \
    | grep -iq 'PostgreSQL custom database dump'
}

restore () {
  : "${FILENAME:=$(list | tail -1)}"  # Use latest dump if not specified.
  if [[ "$GOVUK_ENVIRONMENT" = *"prod"* ]]; then
    : "${REALLY_RESTORE_ONTO_PRODUCTION?}"
  fi
  local s3_url="$BUCKET/$PGHOST/$FILENAME"
  s3_url="$s3_url" dump_is_readable
  dropdb -ef --if-exists "$PGDATABASE"
  aws s3 cp "$s3_url" - | progress | pg_restore -Cd postgres --no-comments
}

subcommand=${1:-}
[[ $(type -t "$subcommand") == function ]] || usage

[[ "${VERBOSE:-0}" -ge 1 ]] && set -x
$subcommand "$@"
echo "done"
