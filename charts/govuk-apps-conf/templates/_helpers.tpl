{{/*
Expand the name of the chart.
*/}}
{{- define "govuk-apps-conf.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "govuk-apps-conf.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "govuk-apps-conf.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "govuk-apps-conf.labels" -}}
helm.sh/chart: {{ include "govuk-apps-conf.chart" . }}
{{ include "govuk-apps-conf.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "govuk-apps-conf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "govuk-apps-conf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Construct the domain name suffixes for internal and external services.
*/}}
{{- define "govuk.internalDomainSuffix" -}}
{{- printf "%s.%s" .Release.Namespace .Values.clusterDomain }}
{{- end }}
{{- define "govuk.externalDomainSuffix" -}}
{{- printf "eks.%s.%s" .Values.govukEnvironment .Values.govukDomainExternal }}
{{- end }}
