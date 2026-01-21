{{/*
Define a Sentry ExternalSecret template
*/}}
{{- define "govuk-application-template.sentry" -}}
{{- if .Values.sentry.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "govuk-application-template.fullname" . }}-sentry
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
  annotations:
    kubernetes.io/description: >
      Client key for the associated Sentry project.
spec:
  refreshInterval: {{ .Values.sentry.refreshInterval | default "1h" }}
  secretStoreRef:
    name: {{ .Values.sentry.secretStoreName | default "aws-secretsmanager" }}
    kind: ClusterSecretStore
  target:
    deletionPolicy: {{ .Values.sentry.deletionPolicy | default "Delete" }}
    name: {{ include "govuk-application-template.fullname" . }}-sentry
  data:
    - secretKey: dsn
      remoteRef:
        key: {{ .Values.sentry.secretKey | default "govuk/common/sentry" }}
        property: {{ .Values.sentry.dsnProperty | default (printf "%s-dsn" (include "govuk-application-template.name" .)) }}
{{- end }}
{{- end }}