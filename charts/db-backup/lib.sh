# shellcheck shell=bash
export LC_ALL=C.UTF-8  # Prevent i18n from affecting command outputs (e.g. `type`).
export HOME=${TMPDIR:-/tmp}  # For aws-cli and the mysql* tools.

usage () {
  self=$(basename "$0")
  cat >&2 <<EOF
$self is a tool for streaming database dumps to/from Amazon S3 (or
compatible), for backup and to copy data between environments.
EOF
  exit 64
}

progress () {
  stdbuf -eL -- pv -fi 10 -F '%t %r %b'
}

# List available backups in ascending date order.
list () {
  local db_name_re
  db_name_re=$(echo "$DB_DATABASE" | tr _- .)
  aws s3 ls "$BUCKET/$DB_HOST/" | grep -Eo "[-0-9:TZ_]+-$db_name_re\.gz"
}

: "${GOVUK_ENVIRONMENT:?required}"
: "${DB_USER:=aws_db_admin}"
: "${DB_PASSWORD:?required}"
: "${DB_HOST:?required}"
: "${DB_DATABASE:?required}"
: "${BUCKET:=s3://govuk-$GOVUK_ENVIRONMENT-database-backups}"
readonly GOVUK_ENVIRONMENT DB_USER DB_PASSWORD DB_HOST DB_DATABASE BUCKET
