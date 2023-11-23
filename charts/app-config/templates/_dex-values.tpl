{{- define "app-config.dex-values" -}}
replicaCount: {{ .Values.replicaCount | default 1 }}
config:
  issuer: "https://dex.{{ .Values.externalDomainSuffix }}"
  oauth2:
    skipApprovalScreen: true
  storage:
    type: kubernetes
    config:
      inCluster: true
  connectors:
    - name: GitHub
      id: github
      type: github
      config:
        clientID: "$GITHUB_CLIENT_ID"
        clientSecret: "$GITHUB_CLIENT_SECRET"
        redirectURI: "https://dex.{{ .Values.externalDomainSuffix}}/callback"
        orgs:
          - name: alpgagov
            teams:
              - gov-uk
              - gov-uk-production-deploy
        teamNameField: both
        useLoginAsID: true
  staticClients:
    - name: argo-workflows
      idEnv: ARGO_WORKFLOWS_CLIENT_ID
      secretEnv: ARGO_WORKFLOWS_CLIENT_SECRET
      redirectURIs:
        - https://argo-workflows.{{ .Values.externalDomainSuffix }}/oauth2/callback
    - name: argocd
      idEnv: ARGOCD_CLIENT_ID
      secretEnv: ARGOCD_CLIENT_SECRET
      redirectURIs:
        - https://argo.{{ .Values.externalDomainSuffix }}/auth/callback
    - name: grafana
      idEnv: GRAFANA_CLIENT_ID
      secretEnv: GRAFANA_CLIENT_SECRET
      redirectURIs:
        - https://grafana.{{ .Values.externalDomainSuffix }}/login/generic_outh
    - name: prometheus
      idEnv: PROMETHEUS_CLIENT_ID
      secretEnv: PROMETHEUS_CLIENT_SECRET
      redirectURIs:
        - https://prometheus.{{ .Values.externalDomainSuffix }}/oauth2/callback
    - name: alert-manager
      idEnv: ALERT_MANAGER_CLIENT_ID
      secretEnv: ALERT_MANAGER_CLIENT_SECRET
      redirectURIs:
        - https://alertmanager.{{ .Values.externalDomainSuffix }}/oauth2/callback
envVars:
  - name: GITHUB_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: govuk-dex-github
        key: clientID
  - name: GITHUB_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-github
        key: clientSecret
  - name: ARGO_WORKFLOWS_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: govuk-dex-argo-workflows
        key: clientID
  - name: ARGO_WORKFLOWS_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-argo-workflows
        key: clientSecret
  - name: ARGOCD_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: govuk-dex-argocd
        key: clientID
  - name: ARGOCD_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-argocd
        key: clientSecret
  - name: GRAFANA_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: govuk-dex-grafana
        key: clientID
  - name: GRAFANA_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-grafana
        key: clientSecret
  - name: PROMETHEUS_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: govuk-dex-prometheus
        key: clientID
  - name: PROMETHEUS_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-prometheus
        key: clientSecret
  - name: ALERT_MANAGER_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: govuk-dex-alertmanager
        key: clientID
  - name: ALERT_MANAGER_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-alertmanager
        key: clientSecret
service:
  ports:
    http:
      port: 80
    https:
      port: 443
ingress:
  enabled: true
  annotations:
    alb.ingress.kubernetes.io/group.name: dex
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-name: dex
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
  className: aws-alb
  hosts:
    - host: dex.{{ .Values.externalDomainSuffix }}
      paths:
        - path: "/*"
          pathType: ImplementationSpecific
{{- end -}}
