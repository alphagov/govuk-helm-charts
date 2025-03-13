{{- define "monitoring-config.ephemeral-kube-prometheus-stack-config" -}}
{{- $clusterId := .Values.clusterId }}
{{- $domainSuffix := .Values.k8sExternalDomainSuffix }}
"alertmanager":
  "alertmanagerSpec":
    "externalUrl": "https://alertmanager.{{ $domainSuffix }}"
    "podAntiAffinity": ""
    "podDisruptionBudget":
      "enabled": false
    "replicas": 1
"grafana":
  "env":
    "AWS_ROLE_ARN": "arn:aws:iam::{{ .Values.awsAccountId }}:role/kube-prometheus-stack-grafana-govuk"
  "grafana.ini":
    "auth.generic_oauth":
      "api_url": "https://dex.{{ $domainSuffix }}/userinfo"
      "auth_url": "https://dex.{{ $domainSuffix }}/auth"
      "role_attribute_path": "'Admin'"
      "token_url": "https://dex.{{ $domainSuffix }}/token"
    "server":
      "domain": "grafana.{{ $domainSuffix }}"
  "ingress":
    "enabled": true
    "hosts":
      - "grafana.{{ $domainSuffix }}"
  "replicas": 1
  "serviceAccount":
    "annotations":
      "eks.amazonaws.com/role-arn":
        "arn:aws:iam::{{ .Values.awsAccountId }}:role/kube-prometheus-stack-grafana-{{ $clusterId }}"
"prometheus":
  "prometheusSpec":
    "externalUrl": "https://prometheus.{{ $domainSuffix }}"
    "externalLabels":
      "environment": "{{ $clusterId }}"
    "podAntiAffinity": ""
    "podDisruptionBudget":
      "enabled": false
    "replicas": 1
    "storageSpec":
      "volumeClaimTemplate":
        "spec":
          "resources":
            "requests":
              "storage": "50Gi"
{{- end }}

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
    eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Values.awsAccountId }}:role/tempo-govuk"
metricsGenerator:
  enabled: true
  config:
    storage:
      remote_write:
        - url: >-
            http://prometheus-kube-prometheus-stack-prometheus-0.prometheus-operated.monitoring.svc.cluster.local:9090/api/v1/write
{{- end }}
