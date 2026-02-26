#!/usr/bin/env bash

if [ -n "${SLACK_MESSAGE_BLOCKS}" ]; then
  BLOCKS="\"blocks\": ${SLACK_MESSAGE_BLOCKS},"
else
  BLOCKS=""
fi

function send_message() {
  CHANNEL="${1}"
  echo "Sending message to Slack channel: ${CHANNEL}"
cat <<EOF | curl --json @- "${SLACK_WEBHOOK_ENDPOINT}"
{
  "channel": "#${CHANNEL}",
  "username": "Argo Workflows",
  "text": "${SLACK_MESSAGE_TEXT}",
  ${BLOCKS}
  "icon_emoji": ":argo:"
}
EOF
}

ALERTS_TEAM=$(
  curl -s https://docs.publishing.service.gov.uk/repos.json | \
  jq -r ".[] | select(.app_name == \"${SLACK_APP_REPO}\") | .alerts_team | ltrimstr(\"#\")"
)

echo "Alerts team: ${ALERTS_TEAM}"

if [ -n "${ALERTS_TEAM}" ]; then
  send_message "${ALERTS_TEAM}"
fi

send_message "${SLACK_CHANNEL}"
