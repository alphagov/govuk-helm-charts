{{- define "slack.color" -}}
{{`{{ if and (eq .Status "firing") (eq .CommonLabels.severity "critical") }}#ff0000{{ else if eq .Status "firing" }}#ffa500{{ else }}#008000{{ end }}`}}
{{- end -}}

{{- define "slack.emoji" -}}
{{`{{ if and (eq .Status "firing") (eq .CommonLabels.severity "critical") }}:octagonal_sign:{{ else if eq .Status "firing" }}:warning:{{ else }}:green_tick:{{ end }}`}}
{{- end -}}

{{- define "slack.filterstring" -}}
{{`{{- if .Labels.SortedPairs -}}`}}
{{`%7B{{- range $index, $pair := .Labels.SortedPairs -}}{{- if ne $index 0 }}%2C%20{{ end -}}{{- .Name }}%3D%22{{ .Value | urlquery }}%22{{- end -}}%7D`}}
{{`{{- end }}`}}
{{- end }}

{{- define "slack.pretext" -}}
{{`{{ if eq .Status "firing" }}The following alert is firing:{{ else }}This alert is resolved:{{ end }}`}}
{{- end -}}

{{- define "slack.status" -}}
{{`{{ if eq .Status "firing" }}:fire: Firing{{ else }}:green_tick: Resolved{{ end }}`}}
{{- end -}}

{{- define "slack.title" -}}
{{`{{ if and (eq .Status "firing") (eq .CommonLabels.severity "critical") }}ERROR{{ else if eq .Status "firing" }}WARNING{{ else }}RESOLVED{{ end }}`}}
{{- end -}}