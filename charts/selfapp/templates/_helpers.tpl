{{/*
Base name for resources, e.g. "selfapp"
*/}}
{{- define "selfapp.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/*
Fully qualified name, e.g. "selfapp" (kept simple since this chart is
always installed as a single release named "selfapp")
*/}}
{{- define "selfapp.fullname" -}}
{{- .Release.Name -}}
{{- end -}}

{{/*
Common labels applied to every resource
*/}}
{{- define "selfapp.labels" -}}
app.kubernetes.io/name: {{ include "selfapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/*
NOTE: component-specific selector labels are written directly inline in
each template (app.kubernetes.io/component: mysql|app|web|...) rather than
through a shared helper here. A generic helper that also needs to inject
the component name adds Go-template indirection (passing a synthetic dict
as the "." context) that's easy to get subtly wrong and hard to debug
without a live `helm template` render to check against — inlining is a
few extra lines per file in exchange for being obviously correct by
inspection.
*/}}

