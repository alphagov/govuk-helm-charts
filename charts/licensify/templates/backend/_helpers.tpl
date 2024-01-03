{{/*
Expand the name of the chart.
*/}}
{{- define "licensify.backend.name" -}}
{{- $chartName := default .Chart.Name .Values.licensify.backend.nameOverride }}
{{- printf "%s-%s" $chartName "backend" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "licensify.backend.fullname" -}}
{{- if .Values.licensify.backend.fullnameOverride }}
{{- .Values.licensify.backend.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $chartName := default .Chart.Name .Values.licensify.backend.nameOverride }}
{{- $name := printf "%s-%s" $chartName "backend" -}}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "licensify.backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "licensify.backend.labels" -}}
helm.sh/chart: {{ include "licensify.chart" . }}
{{ include "licensify.backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "licensify.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "licensify.backend.name" . }}
app.kubernetes.io/component: backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "licensify.backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "licensify.backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
