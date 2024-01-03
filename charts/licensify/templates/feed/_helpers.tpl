{{/*
Expand the name of the chart.
*/}}
{{- define "licensify.feed.name" -}}
{{- $chartName := default .Chart.Name .Values.licensify.feed.nameOverride }}
{{- printf "%s-%s" $chartName "feed" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "licensify.feed.fullname" -}}
{{- if .Values.licensify.feed.fullnameOverride }}
{{- .Values.licensify.feed.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $chartName := default .Chart.Name .Values.licensify.feed.nameOverride }}
{{- $name := printf "%s-%s" $chartName "feed" -}}
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
{{- define "licensify.feed.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "licensify.feed.labels" -}}
helm.sh/chart: {{ include "licensify.chart" . }}
{{ include "licensify.feed.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "licensify.feed.selectorLabels" -}}
app.kubernetes.io/name: {{ include "licensify.feed.name" . }}
app.kubernetes.io/component: feed
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "licensify.feed.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "licensify.feed.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
