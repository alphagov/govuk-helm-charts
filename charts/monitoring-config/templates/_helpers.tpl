{{/*
Get helm release
*/}}
{{- define "monitoring-config.helm-release" -}}
{{- $versions := $.Files.Get (printf "helm-versions/%s" $.Values.govukEnvironment) | fromYaml -}}
{{- $version := get $versions (printf "%s %s" .repoURL .chart) -}}
repoURL: {{ .repoURL }}
chart: {{ .chart }}
targetRevision: "{{ $version }}"
{{- end -}}
