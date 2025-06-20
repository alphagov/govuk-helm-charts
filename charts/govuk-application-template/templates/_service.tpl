{{/*
Define a Kubernetes Service template
*/}}
{{- define "govuk-application-template.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "govuk-application-template.fullname" . }}
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type | default "ClusterIP" }}
  ports:
    - name: http
      port: {{ .Values.service.port | default 80 }}
      targetPort: {{ .Values.service.targetPort | default 3000 }}
      protocol: TCP
  selector:
    {{- include "govuk-application-template.selectorLabels" . | nindent 4 }}
{{- end }}