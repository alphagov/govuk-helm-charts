{{/*
Define a basic Kubernetes Deployment template
*/}}
{{- define "govuk-application-template.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "govuk-application-template.fullname" . }}
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount | default 1 }}
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      {{- include "govuk-application-template.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "govuk-application-template.selectorLabels" . | nindent 8 }}
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "Always" }}
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "govuk-application-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "govuk-application-template.fullname" -}}
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
Common labels
*/}}
{{- define "govuk-application-template.labels" -}}
helm.sh/chart: {{ include "govuk-application-template.chart" . }}
{{ include "govuk-application-template.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "govuk-application-template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "govuk-application-template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "govuk-application-template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}