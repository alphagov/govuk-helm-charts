#!/bin/bash
set -euo pipefail

export LC_ALL=C.UTF-8  # Prevent i18n from affecting command outputs (e.g. `type`).
export HOME=${TMPDIR:-/tmp}  # For aws-cli and the mysql* tools.

usage () {
  self=$(basename "$0")
  cat >&2 <<EOF
$self is a tool for streaming mysqldump output to/from Amazon S3 (or
compatible), for backup and to copy data between environments.
EOF
  exit 64
}

progress () {
  stdbuf -eL -- pv -fi 10 -F '%t %r %b'
}

backup () {
  local s3_path
  s3_path="$DB_HOST/$(date -u +%Y-%m-%dT%H%M%SZ)-$DB_DATABASE.gz"
  mysqldump --single-transaction "$DB_DATABASE" \
    | progress | gzip -c | aws s3 cp - "$BUCKET/$s3_path"
}

# List available backups in ascending date order.
list () {
  local db_name_re
  db_name_re=$(echo "$DB_DATABASE" | tr _- .)
  aws s3 ls "$BUCKET/$DB_HOST/" | grep -Eo "[-0-9:TZ_]+-$db_name_re\.gz"
}

dump_is_readable () {
  set +o pipefail  # We expect SIGPIPE here, but only here.
  (aws s3 cp "$s3_url" - 2>/dev/null) | gzip -cd | head -n5 \
    | tee /dev/fd/2 | grep 'MySQL dump' >/dev/null 2>&1
  local ret=$?
  set -o pipefail
  return $ret
}

restore () {
  : "${FILENAME:=$(list | tail -1)}"  # Use latest dump if not specified.
  if [[ "$GOVUK_ENVIRONMENT" = *"prod"* ]]; then
    : "${REALLY_RESTORE_ONTO_PRODUCTION?}"
  fi
  local s3_url="$BUCKET/$DB_HOST/$FILENAME"
  s3_url="$s3_url" dump_is_readable
  mysqladmin drop -f "$DB_DATABASE" || true
  mysqladmin create "$DB_DATABASE"
  aws s3 cp "$s3_url" - | gzip -cd | progress | mysql "$DB_DATABASE"
}

write_config () {
  cat > "$HOME/.my.cnf" <<EOF
[client]
user=$DB_USER
password=$DB_PASSWORD
host=$DB_HOST
[mysqldump]
set-gtid-purged=OFF  # https://bugs.mysql.com/bug.php?id=109685#c530123
EOF
}

subcommand=${1:-}
[[ $(type -t "$subcommand") == function ]] || usage

: "${GOVUK_ENVIRONMENT:?required}"
: "${DB_USER:=aws_db_admin}"
: "${DB_PASSWORD:?required}"
: "${DB_HOST:?required}"
: "${DB_DATABASE:?required}"
: "${BUCKET:=s3://govuk-$GOVUK_ENVIRONMENT-database-backups}"
readonly GOVUK_ENVIRONMENT DB_USER DB_PASSWORD DB_HOST DB_DATABASE BUCKET

write_config
[[ "${VERBOSE:-0}" -ge 1 ]] && set -x
$subcommand "$@"
echo "done"
