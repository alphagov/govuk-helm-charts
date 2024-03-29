{{- define "app-config.dex-values" -}}
replicaCount: {{ .Values.replicaCount | default 1 }}
config:
  issuer: "https://dex.{{ .Values.k8sExternalDomainSuffix }}"
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
        redirectURI: "https://dex.{{ .Values.k8sExternalDomainSuffix }}/callback"
        orgs:
          - name: {{ .Values.monitoring.authorisation.githubOrganisation }}
            teams: {{ list
              .Values.monitoring.authorisation.readOnlyGithubTeam
              .Values.monitoring.authorisation.readWriteGithubTeam
            | uniq | toYaml | nindent 14 }}
        teamNameField: both
        useLoginAsID: true
  staticClients:
    - name: argo-workflows
      idEnv: ARGO_WORKFLOWS_CLIENT_ID
      secretEnv: ARGO_WORKFLOWS_CLIENT_SECRET
      redirectURIs:
        - https://argo-workflows.{{ .Values.k8sExternalDomainSuffix }}/oauth2/callback
    - name: argocd
      idEnv: ARGOCD_CLIENT_ID
      secretEnv: ARGOCD_CLIENT_SECRET
      redirectURIs:
        - https://argo.{{ .Values.k8sExternalDomainSuffix }}/auth/callback
    - name: grafana
      idEnv: GRAFANA_CLIENT_ID
      secretEnv: GRAFANA_CLIENT_SECRET
      redirectURIs:
        - https://grafana.{{ .Values.k8sExternalDomainSuffix }}/login/generic_oauth
    - name: prometheus
      idEnv: PROMETHEUS_CLIENT_ID
      secretEnv: PROMETHEUS_CLIENT_SECRET
      redirectURIs:
        - https://prometheus.{{ .Values.k8sExternalDomainSuffix }}/oauth2/callback
    - name: alert-manager
      idEnv: ALERT_MANAGER_CLIENT_ID
      secretEnv: ALERT_MANAGER_CLIENT_SECRET
      redirectURIs:
        - https://alertmanager.{{ .Values.k8sExternalDomainSuffix }}/oauth2/callback
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
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
  className: aws-alb
  hosts:
    - host: dex.{{ .Values.k8sExternalDomainSuffix }}
      paths:
        - path: "/*"
          pathType: ImplementationSpecific
{{- end -}}
