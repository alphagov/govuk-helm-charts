{{- define "monitoring-config.ephemeral-tempo-config" }}
{{- $clusterId := .Values.clusterId }}
storage:
  trace:
    backend: s3
    s3:
      bucket: govuk-{{ $clusterId }}-tempo
      region: eu-west-1
      endpoint: s3.dualstack.eu-west-1.amazonaws.com
serviceAccount:
  name: tempo
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Values.awsAccountId }}:role/tempo-{{ $clusterId }}"
metricsGenerator:
  enabled: true
  config:
    storage:
      remote_write:
        - url: >-
            http://prometheus-kube-prometheus-stack-prometheus-0.prometheus-operated.monitoring.svc.cluster.local:9090/api/v1/write
{{- end }}
