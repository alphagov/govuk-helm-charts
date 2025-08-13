{{/*
Define Redis Deployment template
*/}}
{{- define "govuk-application-template.redis.deployment" -}}
{{- if .Values.redis.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "govuk-application-template.fullname" . }}-redis
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
    app.kubernetes.io/component: redis
spec:
  replicas: 1
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      {{- include "govuk-application-template.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: redis
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        {{- include "govuk-application-template.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: redis
    spec:
      automountServiceAccountToken: false
      enableServiceLinks: false
      securityContext:
        seccompProfile:
          type: RuntimeDefault
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      volumes:
        - name: config
          configMap:
            name: {{ include "govuk-application-template.fullname" . }}-redis-config
        - name: storage
          persistentVolumeClaim:
            claimName: {{ include "govuk-application-template.fullname" . }}-redis
      containers:
        - name: redis
          image: "{{ .Values.redis.image.repository | default "redis" }}:{{ .Values.redis.image.tag | default "7-alpine" }}"
          imagePullPolicy: {{ .Values.redis.image.pullPolicy | default "IfNotPresent" }}
          command: ["redis-server", "/etc/redis/redis.conf"]
          ports:
            - name: redis
              containerPort: 6379
          livenessProbe:
            tcpSocket:
              port: 6379
            failureThreshold: 3
            periodSeconds: 5
            timeoutSeconds: 20
          readinessProbe:
            tcpSocket:
              port: 6379
            failureThreshold: 3
            periodSeconds: 5
            timeoutSeconds: 20
          startupProbe:
            tcpSocket:
              port: 6379
            failureThreshold: 5
            periodSeconds: 5
            timeoutSeconds: 20
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: config
              mountPath: /etc/redis/redis.conf
              subPath: redis.conf
            - name: storage
              mountPath: /data
          {{- with .Values.redis.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
{{- end }}
{{- end }}

{{/*
Define Redis Service template
*/}}
{{- define "govuk-application-template.redis.service" -}}
{{- if .Values.redis.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "govuk-application-template.fullname" . }}-redis
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
    app.kubernetes.io/component: redis
spec:
  type: {{ .Values.redis.service.type | default "ClusterIP" }}
  ports:
    - name: redis
      port: 6379
      targetPort: 6379
  selector:
    {{- include "govuk-application-template.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: redis
{{- end }}
{{- end }}

{{/*
Define Redis PVC template
*/}}
{{- define "govuk-application-template.redis.pvc" -}}
{{- if .Values.redis.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "govuk-application-template.fullname" . }}-redis
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
    app.kubernetes.io/component: redis
spec:
  storageClassName: {{ .Values.redis.storageClassName | default "gp2" }}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.redis.storage | default "1Gi" }}
{{- end }}
{{- end }}

{{/*
Define Redis ConfigMap template
*/}}
{{- define "govuk-application-template.redis.configmap" -}}
{{- if .Values.redis.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "govuk-application-template.fullname" . }}-redis-config
  labels:
    {{- include "govuk-application-template.labels" . | nindent 4 }}
    app.kubernetes.io/component: redis
data:
  redis.conf: |
    {{- .Values.redis.config | default "save 900 1\nsave 300 10\nsave 60 10000\nappendonly yes\nmaxmemory-policy allkeys-lru" | nindent 4 }}
{{- end }}
{{- end }}