{{/*
Get helm release
*/}}
{{- define "monitoring-config.helm-release" -}}
{{- $envName := "production" -}}
{{- if ne .Values.govukEnvironment "ephemeral" -}}
{{- $envName = $.Values.govukEnvironment -}}
{{- end -}}
{{- $versions := $.Files.Get (printf "helm-versions/%s" $envName) | fromYaml -}}
{{- $version := get $versions (printf "%s %s" .repoURL .chart) -}}
repoURL: {{ .repoURL }}
chart: {{ .chart }}
targetRevision: "{{ $version }}"
{{- end -}}
