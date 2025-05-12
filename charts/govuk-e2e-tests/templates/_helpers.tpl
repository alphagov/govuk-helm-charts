{{/*
Expand the name of the chart.
*/}}
{{- define "govuk-e2e-tests.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "govuk-e2e-tests.chart" -}}
{{- printf "%s-%s" .Release.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "govuk-e2e-tests.labels" -}}
helm.sh/chart: {{ include "govuk-e2e-tests.chart" . }}
{{ include "govuk-e2e-tests.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/arch: {{ .Values.arch }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "govuk-e2e-tests.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
