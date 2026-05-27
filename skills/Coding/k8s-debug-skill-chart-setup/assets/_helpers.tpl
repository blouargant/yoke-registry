{{/*
Canonical label helpers for debug-skill compatibility.

Replace `mychart` everywhere below with your actual chart name (i.e. the
value of `.Chart.Name`). The two templates serve different purposes:

  * mychart.labels         — full set, for `metadata.labels` on every
                              object the chart ships (workloads, services,
                              configmaps, the debug-skill ConfigMaps).
  * mychart.selectorLabels — IMMUTABLE subset, for
                              `spec.selector.matchLabels` AND
                              `spec.template.metadata.labels` on workloads.
                              These are the labels the failing pod carries
                              at runtime — what debug-skill selectors match.

The selector labels are deliberately small (name + instance). Adding
`app.kubernetes.io/version` to selectorLabels would break rolling
upgrades: when the version changes, the new pods no longer match the
Deployment's immutable matchLabels.
*/}}

{{- define "mychart.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Values.component }}
app.kubernetes.io/component: {{ . }}
{{- end }}
{{- end -}}
