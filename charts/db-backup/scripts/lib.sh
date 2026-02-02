# shellcheck shell=bash
export LC_ALL=C.UTF-8  # Prevent i18n from affecting command outputs (e.g. `type`).
export HOME=${TMPDIR:-/tmp}  # For the mysql* tools.

export DB_BACKUP_JOB_START_TIME

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

send_prometheus_terminal_metric () {
  local EXIT_CODE=$?
  set +x # Can't set this on the line above since we need to capture script exit status with $?
  local STATE

  if [ $EXIT_CODE -eq 0 ]; then
    STATE="succeeded"
  else
    STATE="failed"
  fi

  send_prometheus_metric "$@" "$STATE"
}

send_prometheus_metric () {
  # Send metrics to the prometheus pushgateway.
  # If the state is succeeded or failed, also send the duration if the started state was sent earlier
  #
  # Args:
  #   $1 - database engine (postgres, mysql, mongodb)
  #   $2 - operation (backup, transform, restore)
  #   $3 - state (started, succeeded, failed)
  set +x

  local ENGINE="$1"
  local OPERATION="$2"
  local STATE="$3"

  local TIMESTAMP
  TIMESTAMP=$(date +%s)

  local PAYLOAD
  local DURATION_PAYLOAD=""

  # We are not including instance in the grouping key since we don't mind if the instance label is overwritten on the next run by the hostname of the
  # newer instance
  COMMON_GROUPING_KEY="job/db-backup/database_engine/${ENGINE}/database_instance/${DB_HOST}/database_db_name/${DB_DATABASE}/operation/${OPERATION}"
  COMMON_METRIC_LABELS="instance='${HOSTNAME}', database_engine='${ENGINE}', database_instance='${DB_HOST}', database_db_name='${DB_DATABASE}', operation='${OPERATION}'"

  PAYLOAD=$(cat <<EOF
# TYPE db_backup_job_status_timestamp_seconds gauge
db_backup_job_status_timestamp_seconds{${COMMON_METRIC_LABELS}, state='${STATE}'} $TIMESTAMP
EOF
  )

  if [ "$STATE" == "started" ]; then
    DB_BACKUP_JOB_START_TIME="$TIMESTAMP"
  elif [ -n "$DB_BACKUP_JOB_START_TIME" ] && { [ "$STATE" == "succeeded" ] || [ "$STATE" == "failed" ]; }; then
    DURATION=$((TIMESTAMP - DB_BACKUP_JOB_START_TIME))
    DURATION_PAYLOAD=$(cat <<EOF
# TYPE db_backup_job_duration_seconds gauge
db_backup_job_duration_seconds{${COMMON_METRIC_LABELS}, state='${STATE}'} $DURATION
EOF
    )
  fi

  echo "Sending timing job metrics to prometheus pushgateway"
  echo "$PAYLOAD"
  echo "$DURATION_PAYLOAD"
  echo -e "$PAYLOAD\n$DURATION_PAYLOAD\n" | curl --silent --data-binary @- "${PROMETHEUS_PUSHGATEWAY_URL}/metrics/${COMMON_GROUPING_KEY}/state/${STATE}"

  local METRIC_STATE_VALUE
  case "$STATE" in
    failed)
      METRIC_STATE_VALUE=0
      ;;
    running)
      METRIC_STATE_VALUE=1
      ;;
    succeeded)
      METRIC_STATE_VALUE=2
      ;;
    *)
      METRIC_STATE_VALUE=-1
      ;;
  esac

  PAYLOAD=$(cat <<EOF
# TYPE db_backup_job_state
db_backup_job_state{${COMMON_METRIC_LABELS}} $METRIC_STATE_VALUE
EOF
  )

  # This has to be a separate push since we don't want to include state in the grouping key
  echo "Sending state metric to prometheus pushgateway"
  echo "$PAYLOAD"
  echo -e "$PAYLOAD\n$DURATION_PAYLOAD\n" | curl --silent --data-binary @- "${PROMETHEUS_PUSHGATEWAY_URL}/metrics/${COMMON_GROUPING_KEY}"
}

: "${GOVUK_ENVIRONMENT:?required}"
: "${DB_USER:=aws_db_admin}"
: "${DB_PASSWORD:=}"
: "${DB_HOST:?required}"
: "${DB_DATABASE:?required}"
: "${DB_OWNER:=$(default_db_owner "$DB_DATABASE")}"
: "${BUCKET:=s3://govuk-$GOVUK_ENVIRONMENT-database-backups}"
readonly GOVUK_ENVIRONMENT DB_USER DB_PASSWORD DB_HOST DB_DATABASE BUCKET
