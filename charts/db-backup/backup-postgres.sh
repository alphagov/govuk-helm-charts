#!/bin/bash
set -euo pipefail

export LC_ALL=C.UTF-8  # Prevent i18n from affecting command outputs (e.g. `type`).
export HOME=${TMPDIR:-/tmp}  # aws-cli hates readonlyRootFilesystem :(

usage () {
  self=$(basename "$0")
  cat >&2 <<EOF
$self is a tool for streaming Postgres pg_dump/pg_restore to/from Amazon S3 (or
compatible), for backup and to copy data between environments.
EOF
  exit 64
}

progress () {
  pv -fi 10 -F '%t %r %b'
}

backup () {
  local s3_path
  s3_path="$PGHOST/$(date -u +%Y-%m-%dT%H%M%SZ)-$PGDATABASE.gz"
  pg_dump -Fc | progress | aws s3 cp - "$BUCKET/$s3_path"
}

# List available backups in ascending date order.
list () {
  local db_name_re
  db_name_re=$(echo "$PGDATABASE" | tr _- .)
  aws s3 ls "$BUCKET/$PGHOST/" | grep -Eo "[-0-9:TZ_]+-$db_name_re\.gz"
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
  aws s3 cp "$s3_url" - | progress \
    | pg_restore -Ccd postgres --if-exists --no-comments
}

subcommand=${1:-}
[[ $(type -t "$subcommand") == function ]] || usage

: "${GOVUK_ENVIRONMENT:?required}"
: "${PGUSER:=aws_db_admin}"
: "${PGPASSWORD:?required}"
: "${PGHOST:?required}"
: "${PGDATABASE:?required}"
: "${BUCKET:=s3://govuk-$GOVUK_ENVIRONMENT-database-backups}"
[[ "${VERBOSE:-0}" -ge 1 ]] && set -x

readonly GOVUK_ENVIRONMENT PGUSER PGPASSWORD PGHOST PGDATABASE BUCKET

$subcommand "$@"
