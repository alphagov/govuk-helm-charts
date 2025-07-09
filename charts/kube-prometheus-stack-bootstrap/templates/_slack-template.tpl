{{- /*
This is a temporary Template until Alertmanager supports Slack Block Kit.
*/}}

{{- define "slack.template" -}}
sendResolved: true
color: |-
  {{ include "slack.color" . }}
username: "Prometheus Alertmanager"
iconURL: "https://avatars3.githubusercontent.com/u/3380462"
pretext: |-
  {{ include "slack.pretext" . }}
title: |-
  {{ include "slack.emoji" . }} {{ include "slack.title" . }}: {{ "{{ .CommonLabels.alertname }}" }}
fields:
- title: "Status"
  value: '{{ include "slack.status" . }}'
  short: true
- title: "Severity"
  value: '{{ include "slack.emoji" . }} {{ "{{ .CommonLabels.severity | title }}" }}'
  short: true
- title: "Environment"
  value: '{{ "{{ .CommonLabels.environment | title }}" }}'
  short: true
actions:
  - text: ":mag: View Alert"
    type: button
    url: '{{`{{ .ExternalURL }}/#/alerts?filter=%7B{{- range $index, $pair := .CommonLabels.SortedPairs }}{{- if $index }}, {{ end }}{{ $pair.Name }}%3D"{{ $pair.Value | urlquery }}"{{- end }}%7D`}}'
  - text: ":no_bell: Silence Alert (2h)"
    type: button
    url: '{{`{{ .ExternalURL }}/#/silences/new?filter=%7B{{- range $index, $pair := .CommonLabels.SortedPairs }}{{- if $index }}, {{ end }}{{ $pair.Name }}%3D"{{ $pair.Value | urlquery }}"{{- end }}%7D`}}'
footer: "Sent by Alertmanager"
apiURL:
  name: alertmanager-receivers
  key: slack_api_url
{{- end -}}