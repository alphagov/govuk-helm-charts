{{- define "monitoring-config.oauth2-proxy.config" -}}
proxyVarsAsSecrets: false
ingress:
  enabled: true
  pathType: Prefix
  hosts: [ "{{ .app }}.{{ .Values.k8sExternalDomainSuffix }}" ]
  annotations:
    alb.ingress.kubernetes.io/load-balancer-name: {{ .app }}
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-Ext-2018-06
extraArgs:
  skip-provider-button: "true"
extraEnv:
  - name: OAUTH2_PROXY_ALLOWED_GROUP
    value: {{ .Values.monitoring.authorisation.readWriteGithubTeam }}
  - name: OAUTH2_PROXY_OIDC_ISSUER_URL
    value: "https://dex.{{ .Values.k8sExternalDomainSuffix }}"
  - name: OAUTH2_PROXY_PROVIDER
    value: oidc
  - name: OAUTH2_PROXY_PROVIDER_DISPLAY_NAME
    value: GitHub
  - name: OAUTH2_PROXY_UPSTREAMS
    value: "http://kube-prometheus-stack-{{ .app }}:{{ .port }}"
  - name: OAUTH2_PROXY_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: govuk-dex-{{ .app }}
        key: clientID
  - name: OAUTH2_PROXY_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-{{ .app }}
        key: clientSecret
  - name: OAUTH2_PROXY_COOKIE_SECRET
    valueFrom:
      secretKeyRef:
        name: govuk-dex-{{ .app }}
        key: cookieSecret
{{- end -}}
