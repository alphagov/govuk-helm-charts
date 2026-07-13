#!/bin/bash
set -euo pipefail

################################################################################
# Script Name: export-parquet.sh
# Description: Starts S3 Parquet exports for multiple RDS databases at the  
#              same time using their latest system snapshots, limits concurrency
#              to AWS account limits, and monitors tasks to completion.
# 
# Prerequisites:
#   - AWS CLI
#   - jq (for JSON parsing)
#   - AWS IAM permissions to read RDS system snapshots and write to S3
#     (rds:DescribeDBSnapshots, rds:StartExportTask, and iam:PassRole).
#
# Expected Environment Variables:
#   AWS_REGION:      Target AWS region (e.g., eu-west-1).
#   S3_BUCKET:       Target S3 bucket for the Parquet exports.
#   IAM_ROLE_ARN:    IAM Role that RDS assumes to write to the S3 bucket.
#   KMS_KEY_ID:      KMS Key used to encrypt the S3 export files.
#   DB_TABLES_JSON:  JSON mapping database identifiers to target tables.
#                    Example structure:
#                    {
#                      "database-1": ["table_a", "table_b"],
#                      "database-2": ["table_c"]
#                    }
#
# Design Notes:
#   - Each database export runs in its own background process (subshell) so
#     multiple databases can export in parallel.
#   - AWS allows a maximum of 5 concurrent export tasks per account, so each
#     process checks the current count before submitting and waits if the
#     limit is reached.
#   - Every process writes its outcome to a status file (/tmp/export_<db>.status)
#     because background subshells cannot return values to the parent script
#     any other way.
################################################################################

############################################
# Log Message Helper
############################################
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

############################################
# Status Tracking Helper
############################################
# Background processes run in subshells, so they cannot update variables in
# the main script. Instead, each database writes its result to its own file
# (one file per database, so parallel exports don't overwrite each other).
write_status() {
  local db_id="$1"
  local status_code="$2"
  local details
  details=$(tr '\n' ' ' <<<"$3")
  local status_file="/tmp/export_${db_id}.status"
  echo "STATUS=$status_code" > "$status_file"
  echo "DETAILS=$details" >> "$status_file"
}

############################################
# Check Required Variables & Tools
############################################
required_vars=(
  AWS_REGION
  S3_BUCKET
  IAM_ROLE_ARN
  KMS_KEY_ID
  DB_TABLES_JSON
)

# Stop the script if any required variable is missing
for v in "${required_vars[@]}"; do
  # Check if the variable is empty or unset using indirect expansion
  if [[ -z "${!v:-}" ]]; then
    echo "ERROR: Missing required env var: $v"
    exit 1
  fi
done

# Stop the script if AWS CLI or jq is not installed
for tool in aws jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: Required tool '$tool' is not installed."
    exit 1
  }
done

############################################
# Export Function for a Single Database
############################################
export_snapshot_to_parquet() {
  local db_id="$1"
  local tables="$2"
  local status_file="/tmp/export_${db_id}.status"

  # Safety net: if this function exits early for any unexpected reason
  # (e.g. a crash, a signal, or a bug we didn't anticipate), make sure a
  # status file still gets written. Otherwise the summary at the end would
  # have no record of this database at all.
  # Variables are expanded during registration so the trap uses the correct unique path.
  trap 'if [[ ! -f "'"$status_file"'" ]]; then write_status "'"$db_id"'" "FAILED" "Workflow process exited or was terminated unexpectedly"; fi' EXIT

  log "[$db_id] Starting export workflow"

  # If no tables are specified, skip this database
  if [[ -z "$tables" ]]; then
    log "[$db_id] No tables provided. Skipping."
    write_status "$db_id" "SKIPPED" "No tables provided."
    return 0
  fi

  log "[$db_id] Fetching latest snapshot"

  # Check AWS for automated system snapshots, sort them by newest first,
  # and get the ID of the latest one.
  local snapshot_info
  if ! snapshot_info=$(
    aws rds describe-db-snapshots \
      --region "$AWS_REGION" \
      --snapshot-type automated \
      --db-instance-identifier "$db_id" \
      --query "reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0].[DBSnapshotArn,DBSnapshotIdentifier]" \
      --output text 2>&1
  ); then
    log "[$db_id] Failed to describe snapshots: $snapshot_info"
    write_status "$db_id" "FAILED" "Describe snapshots failed: $snapshot_info"
    return 1
  fi

  # Read the snapshot details into a variable
  local snapshot_arn
  read -r snapshot_arn _ <<< "$snapshot_info"

  # Stop if no snapshot was found
  if [[ -z "${snapshot_arn:-}" || "$snapshot_arn" == "None" ]]; then
    log "[$db_id] No snapshot found"
    write_status "$db_id" "FAILED" "No automated snapshot found."
    return 1
  fi

  local current_date
  current_date=$(date -u '+%Y-%m-%d')

  # Define the S3 folder path: parquet/landing/YYYY-MM-DD/database-name
  local s3_folder_name="parquet/landing/$current_date/$db_id"

  # Create a unique export task ID (database name + timestamp)
  local export_id
  export_id="$db_id-$(date -u '+%Y%m%d%H%M%S')"

  # Convert the table text list into a Bash list (array)
  # so the AWS tool can process multiple tables correctly
  read -r -a table_array <<< "$tables"

  ############################################
  # Submit Export Task (with AWS limit safety)
  ############################################
  # AWS only allows 5 export tasks running at once per account. Before
  # submitting, we check how many are currently running. If we're at the
  # limit, we wait 60 seconds and check again, up to 10 times (10 minutes)
  # before giving up on this database.
  local max_submit_attempts=10  # 10 attempts * 60 seconds = 10 minutes maximum wait
  local submit_attempt=0

  while true; do
    local active_count
    # Safely fetch active exports across the account
    if ! active_count=$(aws rds describe-export-tasks \
      --region "$AWS_REGION" \
      --query "length(ExportTasks[?Status=='STARTING' || Status=='IN_PROGRESS'])" \
      --output text 2>/dev/null); then
      active_count="0"
    fi

    # Ensure active_count is an integer
    if [[ ! "$active_count" =~ ^[0-9]+$ ]]; then
      active_count=0
    fi

    if [[ "$active_count" -ge 5 ]]; then
      submit_attempt=$((submit_attempt + 1))
      if [[ "$submit_attempt" -ge "$max_submit_attempts" ]]; then
        log "[$db_id] Exceeded maximum submission wait time of $((max_submit_attempts)) minutes. Giving up."
        write_status "$db_id" "FAILED" "Timed out waiting for an active export slot (AWS limit of 5 is active)"
        return 1
      fi
      log "[$db_id] Already $active_count export tasks active (AWS limit is 5). Waiting 60 seconds (Attempt $submit_attempt/$max_submit_attempts)..."
      sleep 60
      continue
    fi

    log "[$db_id] Submitting export task to S3"

    # Start the export task and handle concurrency limits or errors
    local submit_output
    if submit_output=$(aws rds start-export-task \
      --region "$AWS_REGION" \
      --export-task-identifier "$export_id" \
      --source-arn "$snapshot_arn" \
      --s3-bucket-name "$S3_BUCKET" \
      --s3-prefix "$s3_folder_name" \
      --iam-role-arn "$IAM_ROLE_ARN" \
      --kms-key-id "$KMS_KEY_ID" \
      --export-only "${table_array[@]}" 2>&1); then
      log "[$db_id] Export task $export_id submitted successfully"
      break
    else
      if [[ "$submit_output" == *"ExportTaskLimitReachedFault"* ]]; then
        # Fallback: even though we already checked the active count above,
        # another database's process may have submitted at nearly the same
        # time and pushed us over the limit anyway. Treat this the same as
        # hitting the limit ourselves.
        submit_attempt=$((submit_attempt + 1))
        if [[ "$submit_attempt" -ge "$max_submit_attempts" ]]; then
          log "[$db_id] Exceeded maximum submission wait time of $((max_submit_attempts)) minutes due to AWS limits. Giving up."
          write_status "$db_id" "FAILED" "Timed out due to AWS ExportTaskLimitReachedFault"
          return 1
        fi
        log "[$db_id] AWS reported export limit reached. Waiting 60 seconds (Attempt $submit_attempt/$max_submit_attempts)..."
        sleep 60
      else
        log "[$db_id] Failed to start export task: $submit_output"
        write_status "$db_id" "FAILED" "Submission failed: $submit_output"
        return 1
      fi
    fi
  done

  ############################################
  # Monitor the Export Task to Completion
  ############################################
  # Check the export status every 60 seconds. Give up monitoring after 30
  # minutes by default (override with EXPORT_TIMEOUT_SECS) so a stuck
  # export can't hang the whole script forever.
  #
  # Under normal conditions exports complete in under 20 minutes, so the
  # 30-minute timeout is padding for slow/larger exports — if a task is
  # still running past 30 minutes, something is likely stuck and it's
  # safe to stop waiting on it.
  #
  # IMPORTANT: this timeout only stops the SCRIPT from watching the task —
  # it does NOT cancel the export task on AWS. The export keeps running in
  # the background and may still complete (or fail) after we've already
  # reported this database as FAILED. It also still counts toward AWS's
  # limit of 5 concurrent export tasks until it actually finishes on AWS's
  # side, so it can block other databases from submitting.
  log "[$db_id] Monitoring export task $export_id"
  
  local check_interval=60
  # Allow the timeout to be configured via env var, defaulting to half an hour (1800 seconds)
  local max_monitor_seconds=${EXPORT_TIMEOUT_SECS:-1800} 
  local monitor_start=$SECONDS

  while true; do
    # Calculate elapsed time in this loop
    local elapsed=$(( SECONDS - monitor_start ))
    if [[ "$elapsed" -ge "$max_monitor_seconds" ]]; then
      log "[$db_id] Monitoring timed out after $(( elapsed / 60 )) minutes. Stopping."
      write_status "$db_id" "FAILED" "Export task exceeded the maximum monitoring timeout of $(( max_monitor_seconds / 60 )) minutes."
      return 1
    fi

    local task_info
    # Handle descriptive errors or transient network failures during polling
    if ! task_info=$(aws rds describe-export-tasks \
      --region "$AWS_REGION" \
      --export-task-identifier "$export_id" \
      --query "ExportTasks[0].[Status,FailureCause,PercentProgress]" \
      --output json 2>/dev/null) || [[ -z "$task_info" || "$task_info" == "null" ]]; then
      log "[$db_id] Warning: Could not retrieve task status. Retrying in $check_interval seconds..."
      sleep "$check_interval"
      continue
    fi

    local task_status
    local failure_cause
    local percent_progress

    task_status=$(jq -r '.[0]' <<<"$task_info")
    failure_cause=$(jq -r '.[1]' <<<"$task_info")
    percent_progress=$(jq -r '.[2]' <<<"$task_info")

    if [[ "$failure_cause" == "null" ]]; then
      failure_cause=""
    fi

    log "[$db_id] Status: $task_status | Progress: $percent_progress% | Elapsed: $(( elapsed / 60 ))m"

    # Record the outcome with a specific reason in each case, so the final
    # summary can tell the difference between "succeeded", "failed because
    # of X", and "was cancelled" instead of just a generic pass/fail.
    case "$task_status" in
      COMPLETE)
        log "[$db_id] Export completed successfully!"
        write_status "$db_id" "COMPLETE" "Success"
        return 0
        ;;
      FAILED)
        log "[$db_id] Export failed: $failure_cause"
        write_status "$db_id" "FAILED" "$failure_cause"
        return 1
        ;;
      CANCELED)
        log "[$db_id] Export was canceled"
        write_status "$db_id" "FAILED" "Export task was canceled."
        return 1
        ;;
      STARTING|IN_PROGRESS|CANCELING)
        # Continue waiting
        ;;
      *)
        log "[$db_id] Unknown status received: $task_status. Continuing to monitor..."
        ;;
    esac

    sleep "$check_interval"
  done
}
############################################
# Main Execution Entrypoint
############################################
db_list=()

# Read the JSON variable, find each database, and start its
# export in the background
while IFS= read -r db; do
  tables=$(jq -r --arg db "$db" '.[$db] | join(" ")' <<<"$DB_TABLES_JSON")
  db_list+=("$db")
  # Remove any leftover status file from a previous run so we don't
  # accidentally read old results for this database.
  rm -f "/tmp/export_${db}.status"
  # Run this database's export in the background so all databases
  # export in parallel. Each one still respects the AWS 5-task limit
  # independently (see above).
  export_snapshot_to_parquet "$db" "$tables" &
done < <(jq -r 'keys[]' <<<"$DB_TABLES_JSON")

############################################
# Wait for All Background Tasks to Finish
############################################
log "Waiting for all background database export workflows to complete..."
wait

log "All background export workflows have finished execution."

# Read back each database's result from its status file and build a report
# grouped by outcome (success / skipped / failed), so it's easy to see at a
# glance which databases need attention and why.
failed=0
success_count=0
failed_count=0
skipped_count=0

failed_reports=()
success_reports=()
skipped_reports=()

for db in "${db_list[@]}"; do
  status_file="/tmp/export_${db}.status"
  
  if [[ -f "$status_file" ]]; then
    status=$(grep "^STATUS=" "$status_file" | cut -d'=' -f2-)
    details=$(grep "^DETAILS=" "$status_file" | cut -d'=' -f2-)
  else
    status="FAILED"
    details="No status file found (process may have been killed or crashed)."
  fi
  
  # Clean up status file
  rm -f "$status_file"

  case "$status" in
    COMPLETE)
      success_reports+=("  - $db: Export finished successfully.")
      success_count=$((success_count + 1))
      ;;
    SKIPPED)
      skipped_reports+=("  - $db: Skipped ($details)")
      skipped_count=$((skipped_count + 1))
      ;;
    FAILED|*)
      failed_reports+=("  - $db: Failed. Reason: $details")
      failed_count=$((failed_count + 1))
      failed=1
      ;;
  esac
done

# Print detailed summary
echo "============================================="
echo "           EXPORT EXECUTION SUMMARY          "
echo "============================================="
echo "Total processed databases: ${#db_list[@]}"
echo "Successful: $success_count"
echo "Failed:     $failed_count"
echo "Skipped:    $skipped_count"
echo "---------------------------------------------"

if [[ ${#success_reports[@]} -gt 0 ]]; then
  echo "Completed Exports:"
  for r in "${success_reports[@]}"; do
    echo "$r"
  done
fi

if [[ ${#skipped_reports[@]} -gt 0 ]]; then
  echo "Skipped Exports:"
  for r in "${skipped_reports[@]}"; do
    echo "$r"
  done
fi

if [[ ${#failed_reports[@]} -gt 0 ]]; then
  echo "Failed Exports:"
  for r in "${failed_reports[@]}"; do
    echo "$r"
  done
fi
echo "============================================="

# Exit with code 1 if anything failed, so Kubernetes (or CI) can detect the
# failure and trigger an alert.
if [[ "$failed" -ne 0 ]]; then
  log "One or more exports failed or encountered errors."
  exit 1
fi

log "All database export tasks completed."
