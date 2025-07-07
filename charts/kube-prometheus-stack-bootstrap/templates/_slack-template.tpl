{{- /*
This is a temporary Template until Alertmanager supports Slack Block Kit.
*/}}

{{- define "slack.template" -}}
sendResolved: true
color: |-
  {{ include "slack.color" . }}
username: "Prometheus Alertmanager"
iconUrl: "https://avatars3.githubusercontent.com/u/3380462"
pretext: |-
  {{ include "slack.pretext" . }}
title: |-
  {{ include "slack.emoji" . }} {{ include "slack.title" . }}: {{ "{{ .CommonLabels.alertname }}" }}
fields: |
  - title: "Status"
    value: {{ include "slack.status" . }}
    short: true
  - title: "Severity"
    value: {{ include "slack.emoji" . }} {{ "{{ .CommonLabels.severity | title }}" }}
    short: true
  - title: "Environment"
    value: {{ "{{ .CommonLabels.environment | title }}" }}
    short: true
actions: |
  {{`{{- if .CommonAnnotations.grafana_path }}`}}
  - text: ":mag: Dashboard"
    type: button
    url: {{`https://grafana.eks.{{ .CommonLabels.environment }}.govuk.digital/{{ .CommonAnnotations.grafana_path }}`}}
  {{`{{- end -}}`}}
  - text: ":mag: View Alert"
    type: button
    url: {{`{{ .ExternalURL }}/#/alerts?filter={{ range .CommonLabels.SortedPairs }}{{ .Name }}%3D"{{ .Value | urlquery }}"%2C{{ end }}`}}
  {{`{{- if .CommonAnnotations.runbook_url }}`}}
  - text: ":orange_book: Runbook"
    type: button
    url: {{ "{{ .CommonAnnotations.runbook_url }}" }}
  {{`{{- end }}`}}
  {{`{{- if .CommonAnnotations.cronjob_uri }}`}}
  - text: ":link: Cronjob URL"
    type: button
    url: {{ "{{ .CommonAnnotations.cronjob_uri }}" }}
  {{`{{- end }}`}}
  - text: ":no_bell: Silence Alert (2h)"
    type: button
    url: {{`{{ .ExternalURL }}/#/silences/new?filter={{ range .CommonLabels.SortedPairs }}{{ .Name }}%3D"{{ .Value | urlquery }}"%2C{{ end }}`}}
  footer: "Sent by Alertmanager"
  apiURL:
    name: alertmanager-receivers
    key: slack_api_url
  {{- end -}}