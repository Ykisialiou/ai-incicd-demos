{{/*
Render a container's resources block from the service's values.

    resources:
      {{- include "acme-common.resources" . | nindent 12 }}

Since 2.4.0 every container-scoped setting lives under `container:`, next to
container.port and container.env, instead of at the top level.
*/}}
{{- define "acme-common.resources" -}}
{{- with .Values.container.resources }}
{{- toYaml . }}
{{- end }}
{{- end -}}
