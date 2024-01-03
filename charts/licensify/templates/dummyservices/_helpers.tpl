{{/*
Expand the name of the chart.
*/}}
{{- define "licensify.dummyservices.name" -}}
{{- $chartName := default .Chart.Name .Values.licensify.dummyservices.nameOverride }}
{{- printf "%s-%s" $chartName "dummyservices" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "licensify.dummyservices.fullname" -}}
{{- if .Values.licensify.dummyservices.fullnameOverride }}
{{- .Values.licensify.dummyservices.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $chartName := default .Chart.Name .Values.licensify.dummyservices.nameOverride }}
{{- $name := printf "%s-%s" $chartName "dummyservices" -}}
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
{{- define "licensify.dummyservices.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "licensify.dummyservices.labels" -}}
helm.sh/chart: {{ include "licensify.chart" . }}
{{ include "licensify.dummyservices.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "licensify.dummyservices.selectorLabels" -}}
app.kubernetes.io/name: {{ include "licensify.dummyservices.name" . }}
app.kubernetes.io/component: dummyservices
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "licensify.dummyservices.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "licensify.dummyservices.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
