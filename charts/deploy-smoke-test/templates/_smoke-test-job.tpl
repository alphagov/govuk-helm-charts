{{- define "deploy-smoke-test.job" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Release.Name }}-smoke-test
  annotations:
    argocd.argoproj.io/hook: PostSync
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  template:
    spec:
      containers:
      - name: smokey
        image: 172025368201.dkr.ecr.eu-west-1.amazonaws.com/smokey:latest
        command: ["bundle", "exec", "cucumber", "--profile", "{{ .govukEnvironment }}", "--strict-undefined", "-t", "@app-{{ .Release.Name }}", "-t", "@replatforming", "-t", "not @notreplatforming and not @not{{ .govukEnvironment }}"]
        env:
        - name: ENVIRONMENT
          value: "{{ .govukEnvironment }}"
        - name: GOVUK_APP_DOMAIN
          value: "{{ .appGovukAppDomain | default (printf "%s.%s.%s" .Release.Namespace .govukEnvironment .govukDomainInternal) }}"
        - name: GOVUK_WEBSITE_ROOT
          value: "{{ .appGovukWebsiteRoot | default (printf "https://www-origin-%s.eks.%s.%s" .Release.Namespace .govukEnvironment .govukDomainExternal) }}"
        # TODO: These PLEK_ overrides should be unnecessary.
        - name: PLEK_SERVICE_PUBLISHER_URI
          value: "{{ .Values.appPlekServicePublisherUri | default (printf "http://publisher-%s.eks.%s.%s" .Release.Namespace .govukEnvironment .govukDomainExternal) }}"
        - name: PLEK_SERVICE_FRONTEND_URI
          value: "{{ .Values.appPlekServiceFrontendUri | default (printf "http://frontend.%s.%s" .Release.Namespace .govukDomainInternal) }}"
        - name: PLEK_SERVICE_SIGNON_URI
          value: "{{ .Values.appPlekServiceSignonUri | default (printf "http://signon-%s.eks.%s.%s" .Release.Namespace .govukEnvironment .govukDomainExternal) }}"
        - name: SIGNON_EMAIL
          value: "signon@alphagov.co.uk"
        - name: SIGNON_PASSWORD
          valueFrom:
            secretKeyRef:
              name: smokey
              key: signon_password
        - name: AUTH_USERNAME
          valueFrom:
            secretKeyRef:
              name: smokey
              key: auth_username
        - name: AUTH_PASSWORD
          valueFrom:
            secretKeyRef:
              name: smokey
              key: auth_password
      restartPolicy: Never # TODO: Add restart policy to alleviate flakiness
  backoffLimit: 2
{{- end -}}
