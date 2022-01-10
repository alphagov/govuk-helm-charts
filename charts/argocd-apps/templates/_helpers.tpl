{{- define "govukIngress" }}
ingress:
  enabled: true
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/healthcheck-path: /healthcheck/ready
    alb.ingress.kubernetes.io/load-balancer-name: {{ .name }}
  hosts:
  - host: {{ .host }}
    paths:
    - path: /
      pathType: Prefix
{{- end }}
