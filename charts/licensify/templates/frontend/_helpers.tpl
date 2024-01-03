{{/*
Expand the name of the chart.
*/}}
{{- define "licensify.frontend.name" -}}
{{- $chartName := default .Chart.Name .Values.licensify.frontend.nameOverride }}
{{- printf "%s-%s" $chartName "frontend" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "licensify.frontend.fullname" -}}
{{- if .Values.licensify.frontend.fullnameOverride }}
{{- .Values.licensify.frontend.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $chartName := default .Chart.Name .Values.licensify.frontend.nameOverride }}
{{- $name := printf "%s-%s" $chartName "frontend" -}}
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
{{- define "licensify.frontend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "licensify.frontend.labels" -}}
helm.sh/chart: {{ include "licensify.chart" . }}
{{ include "licensify.frontend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "licensify.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "licensify.frontend.name" . }}
app.kubernetes.io/component: frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "licensify.frontend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "licensify.frontend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
