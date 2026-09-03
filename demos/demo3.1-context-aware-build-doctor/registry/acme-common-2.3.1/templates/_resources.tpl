{{/*
Render a container's resources block from the service's values.

    resources:
      {{- include "acme-common.resources" . | nindent 12 }}
*/}}
{{- define "acme-common.resources" -}}
{{- with .Values.resources }}
{{- toYaml . }}
{{- end }}
{{- end -}}
