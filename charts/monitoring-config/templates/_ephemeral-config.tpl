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
"defaultRules":
  "disabled":
    "KubePodNotReady": true
    "NodeClockNotSynchronising": true
    "NodeClockSkewDetected": true
    "NodeNetworkReceiveErrs": true
    "NodeNetworkTransmitErrs": true
    "NodeRAIDDegraded": true
    "NodeRAIDDiskFailure": true
  "rules":
    "kubeApiserverAvailbility": false
    "kubeApiserverBurnrate": false
    "kubeApiserverHistogram": false
    "kubeApiserverSlos": false
    "network": false
"grafana":
  "env":
    "AWS_ROLE_ARN": "arn:aws:iam::{{ .Values.awsAccountId }}:role/kube-prometheus-stack-grafana-govuk"
  "envValueFrom":
    "GF_AUTH_GENERIC_OAUTH_CLIENT_ID":
      "secretKeyRef":
        "key": "clientID"
        "name": "dex-client-grafana"
    "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET":
      "secretKeyRef":
        "key": "clientSecret"
        "name": "dex-client-grafana"
  "grafana.ini":
    "auth":
      "oauth_allow_insecure_email_lookup": true
      "oauth_auto_login": true
    "auth.generic_oauth":
      "enabled": true
      "api_url": "https://dex.{{ $domainSuffix }}/userinfo"
      "auth_url": "https://dex.{{ $domainSuffix }}/auth"
      "role_attribute_path": "'Admin'"
      "token_url": "https://dex.{{ $domainSuffix }}/token"
      "scopes": "openid profile email groups"
    "server":
      "domain": "grafana.{{ $domainSuffix }}"
      "root_url": "https://%(domain)s"
  "ingress":
    "enabled": true
    "annotations":
      "alb.ingress.kubernetes.io/scheme": internet-facing
      "alb.ingress.kubernetes.io/target-type": ip
      "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP":80},{"HTTPS":443}]'
      "alb.ingress.kubernetes.io/ssl-redirect": "443"
      "alb.ingress.kubernetes.io/ssl-policy": ELBSecurityPolicy-TLS-1-2-Ext-2018-06
    "hosts":
      - "grafana.{{ $domainSuffix }}"
  "replicas": 1
  "serviceAccount":
    "annotations":
      "eks.amazonaws.com/role-arn":
        "arn:aws:iam::{{ .Values.awsAccountId }}:role/kube-prometheus-stack-grafana-{{ $clusterId }}"
"kubeApiServer":
  "enabled": false
"kubeControllerManager":
  "enabled": false
"kubeEtcd":
  "enabled": false
"kubeScheduler":
  "enabled": false
"kube_state_metrics":
  "selfMonitor":
    "enabled": true
"prometheus":
  "prometheusSpec":
    "externalUrl": "https://prometheus.{{ $domainSuffix }}"
    "externalLabels":
      "environment": "{{ $clusterId }}"
    "evaluationInterval": "1m"
    "podAntiAffinity": ""
    "podDisruptionBudget":
      "enabled": false
    "podMonitorNamespaceSelector":
      "matchExpressions":
        - "key": "no_monitor"
          "operator": "DoesNotExist"
          "values": []
    "podMonitorSelectorNilUsesHelmValues": false
    "probeNamespaceSelector":
      "matchExpressions":
        - "key": "no_monitor"
          "operator": "DoesNotExist"
          "values": []
    "probeSelectorNilUsesHelmValues": false
    "ruleNamespaceSelector":
      "matchExpressions":
        - "key": "no_monitor"
          "operator": "DoesNotExist"
          "values": []
    "ruleSelectorNilUsesHelmValues": false
    "scrapeInterval": "1m"
    "scrapeTimeout": "15s"
    "serviceMonitorNamespaceSelector":
      "matchExpressions":
        - "key": "no_monitor"
          "operator": "DoesNotExist"
          "values": []
    "serviceMonitorSelectorNilUsesHelmValues": false
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
    eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Values.awsAccountId }}:role/tempo-{{ $clusterId }}"
metricsGenerator:
  enabled: true
  config:
    storage:
      remote_write:
        - url: >-
            http://prometheus-kube-prometheus-stack-prometheus-0.prometheus-operated.monitoring.svc.cluster.local:9090/api/v1/write
{{- end }}
