{{/*
Define a PodMonitor template for Prometheus monitoring
*/}}
{{- define "govuk-application-template.podmonitor" -}}
{{- if .Values.monitoring.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: {{ include "govuk-application-template.fullname" . }}
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
spec:
  jobLabel: app.kubernetes.io/name
  selector:
    matchLabels:
      {{- include "govuk-application-template.selectorLabels" . | nindent 6 }}
  podMetricsEndpoints:
  - port: metrics
    path: {{ .Values.monitoring.metricsPath | default "/metrics" }}
    {{- with .Values.monitoring.interval }}
    interval: {{ . }}
    {{- end }}
    {{- with .Values.monitoring.scrapeTimeout }}
    scrapeTimeout: {{ . }}
    {{- end }}
{{- end }}
{{- end }}