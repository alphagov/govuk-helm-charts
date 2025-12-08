{{/*
Expand the name of the chart.
*/}}
{{- define "mirror.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "drift.name" -}}
{{- include "mirror.name" . }}-drift-check
{{- end }}

{{- define "exporter.name" -}}
{{- include "mirror.name" . }}-exporter
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mirror.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "drift.fullname" -}}
{{- include "mirror.fullname" . }}-drift-check
{{- end }}

{{- define "exporter.fullname" -}}
{{- include "mirror.fullname" . }}-exporter
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mirror.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mirror.labels" -}}
helm.sh/chart: {{ include "mirror.chart" . }}
{{ include "mirror.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "drift.labels" -}}
helm.sh/chart: {{ include "mirror.chart" . }}
{{ include "drift.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "exporter.labels" -}}
helm.sh/chart: {{ include "mirror.chart" . }}
{{ include "exporter.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mirror.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mirror.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "drift.selectorLabels" -}}
app.kubernetes.io/name: {{ include "drift.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mirror.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mirror.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "drift.serviceAccountName" -}}
{{ include "mirror.serviceAccountName" .}} {{/*Drift detection uses the same service account*/}}
{{- end }}
