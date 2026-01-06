# shellcheck shell=bash
export LC_ALL=C.UTF-8  # Prevent i18n from affecting command outputs (e.g. `type`).
export HOME=${TMPDIR:-/tmp}  # For the mysql* tools.

usage () {
  self=$(basename "$0")
  cat >&2 <<EOF
$self is a tool for streaming database dumps to/from Amazon S3 (or
compatible), for backup and to copy data between environments.
EOF
  exit 64
}

progress () {
  stdbuf -e0 -- pv -fi 10 -F '%t %r %b'
}

# List available backups in ascending date order.
list () {
  local db_name_re
  db_name_re=$(echo "$DB_DATABASE" | tr _- .)
  s5cmd ls "$BUCKET/$DB_HOST/" | grep -Eo "[-0-9:TZ_]+-$db_name_re\.gz"
}

# foo-bar -> foo_bar
# draft-foo-bar_production -> foo_bar
default_db_owner () {
  echo "${1%_production}" | sed -E 's/^(draft[_-])?(.*)/\2/' | tr - _
}

# Write a pointer file for the specified file
write_pointer () {
  echo -n "${1}" | s5cmd pipe "${BUCKET}/${DB_HOST}/latest.txt"
}

# Determine backup object URI for restores
object_uri () {
  local file_name

  # if FILENAME is not set
  if [ -z "${FILENAME+x}" ]; then
    local latest_pointer
    if latest_pointer=$(s5cmd cat "${BUCKET}/${DB_HOST}/latest.txt" | tr -d '\n'); then
      echo "Latest successful backup: ${latest_pointer}" >&2
      file_name=$(basename "$latest_pointer")
    else
      # return latest dump if getting the pointer file fails
      echo "Failed to get latest pointer file: ${latest_pointer}" >&2
      file_name="$(list | tail -1)"
    fi
  else
    echo "FILENAME specified: ${FILENAME}" >&2
    file_name="${FILENAME}"
  fi

  echo -n "${BUCKET}/${DB_HOST}/${file_name}"
}

: "${GOVUK_ENVIRONMENT:?required}"
: "${DB_USER:=aws_db_admin}"
: "${DB_PASSWORD:=}"
: "${DB_HOST:?required}"
: "${DB_DATABASE:?required}"
: "${DB_OWNER:=$(default_db_owner "$DB_DATABASE")}"
: "${BUCKET:=s3://govuk-$GOVUK_ENVIRONMENT-database-backups}"
readonly GOVUK_ENVIRONMENT DB_USER DB_PASSWORD DB_HOST DB_DATABASE BUCKET
