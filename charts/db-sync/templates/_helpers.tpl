{{/*
Expand the name of the chart.
*/}}
{{- define "db-sync.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "db-sync.fullname" -}}
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
{{- define "db-sync.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "db-sync.labels" -}}
helm.sh/chart: {{ include "db-sync.chart" . }}
{{ include "db-sync.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "db-sync.selectorLabels" -}}
app.kubernetes.io/name: {{ include "db-sync.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "db-sync.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "db-sync.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Default DB port for a dbType.
Usage: include "db-sync.defaultDbPort" "postgres"
*/}}
{{- define "db-sync.defaultDbPort" -}}
{{- if eq . "postgres" -}}
5432
{{- else if eq . "mysql" -}}
3306
{{- else if eq . "documentdb" -}}
27017
{{- end -}}
{{- end }}

{{/*
URI scheme for a dbType.
Usage: include "db-sync.dbUriScheme" "postgres"
*/}}
{{- define "db-sync.dbUriScheme" -}}
{{- if eq . "postgres" -}}
postgres
{{- else if eq . "mysql" -}}
mysql
{{- else if eq . "documentdb" -}}
mongodb
{{- end -}}
{{- end }}

{{/*
Transform DB user default by engine.
Expected dict keys: job
*/}}
{{- define "db-sync.transformUser" -}}
{{- $job := .job -}}
{{- if eq $job.dbType "documentdb" -}}
{{- default "mongoadmin" $job.transformUsername -}}
{{- else if eq $job.dbType "mysql" -}}
{{- default "root" $job.transformUsername -}}
{{- else -}}
{{- default "postgres" $job.transformUsername -}}
{{- end -}}
{{- end }}

{{/*
Build source URI from components unless sourceUri is explicitly set.
Expected dict keys: root, job, jobName
*/}}
{{- define "db-sync.sourceUri" -}}
{{- $root := .root -}}
{{- $job := .job -}}
{{- $jobName := .jobName -}}
{{- if $job.sourceUri -}}
{{- $job.sourceUri -}}
{{- else -}}
	{{- $hostname := default $jobName $job.sourceDbHostname -}}
	{{- if $hostname -}}
		{{- $port := $job.sourceDbPort -}}
		{{- if not $port -}}
			{{- $port = include "db-sync.defaultDbPort" $job.dbType | trim -}}
		{{- end -}}
		{{- $username := default $root.Values.defaultDbUsername $job.sourceDbUsername -}}
		{{- $scheme := include "db-sync.dbUriScheme" $job.dbType | trim -}}
		{{- printf "%s://%s@%s:%s/%s" $scheme $username $hostname $port $job.dbName -}}
	{{- end -}}
{{- end -}}
{{- end }}

{{/*
Build destination URI from components unless destUri is explicitly set.
Expected dict keys: root, job, jobName
*/}}
{{- define "db-sync.destUri" -}}
{{- $root := .root -}}
{{- $job := .job -}}
{{- $jobName := .jobName -}}
{{- if $job.destUri -}}
{{- $job.destUri -}}
{{- else if ne $job.dbType "documentdb" -}}
	{{- $hostname := default $jobName $job.destDbHostname -}}
	{{- if $hostname -}}
		{{- $port := $job.destDbPort -}}
		{{- if not $port -}}
			{{- $port = include "db-sync.defaultDbPort" $job.dbType | trim -}}
		{{- end -}}
		{{- $username := default $root.Values.defaultDbUsername $job.destDbUsername -}}
		{{- $scheme := include "db-sync.dbUriScheme" $job.dbType | trim -}}
		{{- printf "%s://%s@%s:%s/%s" $scheme $username $hostname $port $job.dbName -}}
	{{- end -}}
{{- end -}}
{{- end }}

{{/*
Build transform URI from components unless transformUri is explicitly set.
Expected dict keys: job, transformUser
*/}}
{{- define "db-sync.transformUri" -}}
{{- $job := .job -}}
{{- $transformUser := .transformUser -}}
{{- if $job.transformUri -}}
{{- $job.transformUri -}}
{{- else -}}
	{{- $scheme := include "db-sync.dbUriScheme" $job.dbType | trim -}}
	{{- $port := include "db-sync.defaultDbPort" $job.dbType | trim -}}
	{{- $transformDbName := default $job.dbName $job.transformDbName -}}
	{{- printf "%s://%s@127.0.0.1:%s/%s" $scheme $transformUser $port $transformDbName -}}
{{- end -}}
{{- end }}
