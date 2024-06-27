{{/*
Expand the name of the chart.
*/}}
{{- define "smokey.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "smokey.chart" -}}
{{- printf "%s-%s" .Release.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "smokey.labels" -}}
helm.sh/chart: {{ include "smokey.chart" . }}
{{ include "smokey.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/arch: {{ .Values.arch }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "smokey.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
