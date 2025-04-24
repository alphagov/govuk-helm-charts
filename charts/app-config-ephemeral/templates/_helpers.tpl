{{/*
Get helm release
*/}}
{{- define "helm-release" -}}
{{- $versions := $.Files.Get "helm-versions.yaml" | fromYaml -}}
{{- $version := get $versions (printf "%s %s" .repoURL .chart) -}}
repoURL: {{ .repoURL }}
chart: {{ .chart }}
targetRevision: "{{ $version }}"
{{- end -}}
