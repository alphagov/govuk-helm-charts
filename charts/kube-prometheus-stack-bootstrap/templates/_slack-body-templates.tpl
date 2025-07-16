{{- define "slack.expiringtokenstext" -}}
{{`{{- if .CommonAnnotations.summary }}`}}
*{{`{{ .CommonAnnotations.summary }}`}}*
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.description }}`}}
*Description*:
{{`{{ .CommonAnnotations.description }}`}}
{{`{{ end }}`}}

{{`{{ if .Alerts | len | gt 0 }}`}}
*Expiring Tokens*
================
{{`{{ range .Alerts }}`}}
  {{`{{ if eq .Status "firing" }}`}}
  • api_user: `{{`{{ .Labels.api_user }}`}}`, application: `{{`{{ .Labels.application }}`}}`
    Actions:
     • <{{`{{ $.ExternalURL }}`}}/#/alerts?filter={{- include "slack.filterstring" . -}}|:mag: View Alert>
     • <{{`{{ $.ExternalURL }}`}}/#/silences/new?filter={{- include "slack.filterstring" . -}}|:no_bell: Silence Alert (2h)>
  {{`{{ end }}`}}
{{`{{ end }}`}}
{{`{{ end }}`}}

*Links:*
{{`{{- if .CommonAnnotations.grafana_path }}`}}
• <https://grafana.eks.{{`{{ .CommonLabels.environment }}`}}.govuk.digital/{{`{{ .CommonAnnotations.grafana_path }}`}}|:mag: View Dashboard>
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.runbook_url }}`}}
• <{{`{{ .CommonAnnotations.runbook_url }}`}}|:orange_book: View Runbook>
{{`{{- else }}`}}
• :orange_book: No Runbook has been provided
{{`{{- end }}`}}

{{- end -}}


{{- define "slack.mirrortext" -}}
{{`{{- if .CommonAnnotations.summary }}`}}
*{{`{{ .CommonAnnotations.summary }}`}}*
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.description }}`}}
*Description*:
{{`{{ .CommonAnnotations.description }}`}}
{{`{{ end }}`}}

{{`{{ if .Alerts | len | gt 0 }}`}}
*Mirrors:*
================
{{`{{ range .Alerts }}`}}
  {{`{{ if eq .Status "firing" }}`}}
  • *Backend:* `{{`{{ .Labels.backend }}`}}`

     Actions:
     • <{{`{{ $.ExternalURL }}`}}/#/alerts?filter={{- include "slack.filterstring" . -}}|:mag: View Alert>
     • <{{`{{ $.ExternalURL }}`}}/#/silences/new?filter={{- include "slack.filterstring" . -}}|:no_bell: Silence Alert (2h)>
  {{`{{ end }}`}}
{{`{{ end }}`}}
{{`{{ end }}`}}

*Links:*
{{`{{- if .CommonAnnotations.grafana_path }}`}}
• <https://grafana.eks.{{`{{ .CommonLabels.environment }}`}}.govuk.digital/{{`{{ .CommonAnnotations.grafana_path }}`}}|:mag: View Dashboard>
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.runbook_url }}`}}
• <{{`{{ .CommonAnnotations.runbook_url }}`}}|:orange_book: View Runbook>
{{`{{- else }}`}}
• :orange_book: No Runbook has been provided
{{`{{- end }}`}}

{{- end -}}


{{- define "slack.text" -}}
{{`{{- if .CommonAnnotations.summary }}`}}
*{{`{{ .CommonAnnotations.summary }}`}}*
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.description }}`}}
*Description*:
{{`{{ .CommonAnnotations.description }}`}}
{{`{{ end }}`}}

{{`{{- if .CommonLabels.SortedPairs | len | gt 0 }}`}}
*Labels*:
  {{`{{ range .CommonLabels.SortedPairs }}`}}
  • *{{`{{ .Name }}`}}*: {{`{{ .Value }}`}}
  {{`{{- end }}`}}
{{`{{ end }}`}}

{{`{{ if .Alerts | len | gt 0 }}`}}
*Firing Alerts*
================
{{`{{ range .Alerts }}`}}
  {{`{{ if eq .Status "firing" }}`}}
  • *{{`{{ .Annotations.summary }}`}}*: 
    {{`{{ .Annotations.description }}`}}

     Actions:
     • <{{`{{ $.ExternalURL }}`}}/#/alerts?filter={{- include "slack.filterstring" . -}}|:mag: View Alert>
     • <{{`{{ $.ExternalURL }}`}}/#/silences/new?filter={{- include "slack.filterstring" . -}}|:no_bell: Silence Alert (2h)>
  {{`{{ end }}`}}
{{`{{ end }}`}}
{{`{{ end }}`}}

*Links:*
{{`{{- if .CommonAnnotations.grafana_path }}`}}
• <https://grafana.eks.{{`{{ .CommonLabels.environment }}`}}.govuk.digital/{{`{{ .CommonAnnotations.grafana_path }}`}}|:mag: View Dashboard>
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.runbook_url }}`}}
• <{{`{{ .CommonAnnotations.runbook_url }}`}}|:orange_book: View Runbook>
{{`{{- else }}`}}
• :orange_book: No Runbook has been provided
{{`{{- end }}`}}

{{`{{- if .CommonAnnotations.cronjob_uri }}`}}
• <{{`{{ .CommonAnnotations.cronjob_uri }}`}}|:link: View Cronjob>
{{`{{- end }}`}}

{{- end -}}