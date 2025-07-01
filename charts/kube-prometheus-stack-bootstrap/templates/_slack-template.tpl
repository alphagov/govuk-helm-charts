{{- /*
This is a temporary Template until Alertmanager supports Slack Block Kit.
*/}}

{{- define "slack.template" -}}
sendResolved: true
color: {{ template "slack.color" . }}
username: "Prometheus Alertmanager"
iconUrl: "https://avatars3.githubusercontent.com/u/3380462"
pretext: "{{ template "slack.pretext" . }}"
title: >-
{{ template "slack.emoji" . }} {{ template "slack.title" . }}: {{ .CommonLabels.alertname }}
fields:
- title: "Status"
  value: "{{ template "slack.status" . }}"
  short: true
- title: "Severity"
  value: "{{ template "slack.emoji" . }} {{ .CommonLabels.severity | title }}"
  short: true
- title: "Environment"
  value: "{{ .CommonLabels.environment | title }}"
  short: true
actions:
{{- if .CommonAnnotations.grafana_path -}}
- text: ":mag: Dashboard"
  type: button
  url: "{{ template "slack.dashboardurl" . }}"
{{- end -}}
- text: ":mag: View Alert"
  type: button
  url: "{{ template "slack.alerturl" . }}"
{{- if .CommonAnnotations.runbook_url -}}
- text: ":orange_book: Runbook"
  type: button
  url: "{{ .CommonAnnotations.runbook_url }}"
{{- end -}}
{{- if .CommonAnnotations.cronjob_uri -}}
- text: ":link: Cronjob URL"
  type: button
  url: "{{ .CommonAnnotations.cronjob_uri }}"
{{- end -}}
- text: ":no_bell: Silence Alert (2h)"
  type: button
  url: "{{ template "slack.silenceurl" . }}"
footer: "Sent by Alertmanager"
apiURL:
  name: alertmanager-receivers
  key: slack_api_url
{{- end -}}