{{- define "slack.color" -}}
{{`{{ if and (eq .Status "firing") (eq .CommonLabels.severity "critical") }}#ff0000{{ else if eq .Status "firing" }}#ffa500{{ else }}#008000{{ end }}`}}
{{- end -}}

{{- define "slack.emoji" -}}
{{`{{ if and (eq .Status "firing") (eq .CommonLabels.severity "critical") }}:octagonal_sign:{{ else if eq .Status "firing" }}:warning:{{ else }}:green_tick:{{ end }}`}}
{{- end -}}

{{- define "slack.pretext" -}}
{{`{{ if eq .Status "firing" }}The following alert is firing:{{ else }}This alert is resolved:{{ end }}`}}
{{- end -}}

{{- define "slack.status" -}}
{{`{{ if eq .Status "firing" }}:fire: Firing{{ else }}:green_tick: Resolved{{ end }}`}}
{{- end -}}

{{- define "slack.text" -}}
{{`{{- if .CommonAnnotations.summary }}`}}
*{{`{{ .CommonAnnotations.summary }}`}}*
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.description }}`}}
*Description*:
{{`{{ .CommonAnnotations.description }}`}}
{{`{{ end }}`}}

{{`{{- if .CommonLabels.SortedPairs }}`}}
*Labels*:
  {{`{{ range .CommonLabels.SortedPairs }}`}}
  • *{{`{{ .Name }}`}}*: {{`{{ .Value }}`}}
  {{`{{- end }}`}}
{{`{{ end }}`}}

{{`{{ if .Alerts }}`}}
*Firing Alerts*:
{{`{{ range .Alerts }}`}}
  {{`{{ if eq .Status "firing" }}`}}
  • *{{`{{ .Annotations.summary }}`}}*: 
    {{`{{ .Annotations.description }}`}}
  {{`{{ end }}`}}
{{`{{ end }}`}}
{{`{{ end }}`}}

*Links:*
{{`{{- if .CommonAnnotations.grafana_path }}`}}
• <https://grafana.eks.{{`{{ .CommonLabels.environment }}`}}.govuk.digital/{{`{{ .CommonAnnotations.grafana_path }}`}}|:mag: View Dashboard>
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.runbook_url }}`}}
• <{{`{{ .CommonAnnotations.runbook_url }}`}}|:orange_book: View Runbook>
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.cronjob_uri }}`}}
• <{{`{{ .CommonAnnotations.cronjob_uri }}`}}|:link: View Cronjob>
{{`{{- end }}`}}

{{- end -}}

{{- define "slack.title" -}}
{{`{{ if and (eq .Status "firing") (eq .CommonLabels.severity "critical") }}ERROR{{ else if eq .Status "firing" }}WARNING{{ else }}RESOLVED{{ end }}`}}
{{- end -}}