{{- /*
This is currently unused while we wait for the Prometheus Team to decide whether they want to start supporting 
Slack Block Kit, as Slack Attachments are "deprecated".
*/}}

{{- define "slack.blockkit" -}}
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "{{ template "slack.emoji" . }} {{ template "slack.title" . }}: {{ .CommonLabels.alertname }}"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Status:*\n{{ template "slack.status" . }}"
        },
        {
          "type": "mrkdwn",
          "text": "*Severity:*\n{{ template "slack.emoji" . }} {{ .CommonLabels.severity | title }}"
        },
      ]
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Environment:*\n{{ .CommonLabels.environment | title }}"
        },
      ]
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Description:*\n{{ .CommonAnnotations.description }}"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Key Labels:*\n{{ .CommonLabels.SortedPairs | join "\n" }}"
      }
    },
    {
      "type": "divider"
    },
    {
			"type": "actions",
			"elements": [
				{
					"type": "button",
					"text": {
						"type": "plain_text",
						"text": ":mag: View Alert",
						"emoji": true
					},
					"url": "{{ template "slack.alerturl" . }}"
				},
        {{- if .CommonAnnotations.runbook_url -}}
				{
					"type": "button",
					"text": {
						"type": "plain_text",
						"text": ":orange_book: Open Runbook",
						"emoji": true
					},
					"url": "{{ .CommonAnnotations.runbook_url }}"
				},
        {{- end -}}
        {{- if .CommonAnnotations.cronjob_uri -}}
        {
					"type": "button",
					"text": {
						"type": "plain_text",
						"text": ":link: Cronjob URL",
						"emoji": true
					},
					"url": "{{ .CommonAnnotations.cronjob_uri }}"
				},
        {{- end -}}
        {
					"type": "button",
					"text": {
						"type": "plain_text",
						"text": ":no_bell: Silence Alert (2h)",
						"emoji": true
					},
					"url": "{{ template "slack.silenceurl" . }}"
				},
			]
		},
    {
      "type": "context",
      "elements": [
        {{ if ne .CommonAnnotations.runbook_url false }}
        {
          "type": "mrkdwn",
          "text": "*No Runbook exists for this alert.* Perhaps you should create one?"
        },
        {{ end }}
        {
          "type": "mrkdwn",
          "text": "Alert sent by Alertmanager"
        }
      ]
    }
  ]
}
{{- end -}}