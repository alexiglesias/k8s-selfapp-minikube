{{/*
Chart name, e.g. "selfapp".
*/}}
{{- define "selfapp.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/*
Prefix for every resource name. Uses the release name, so a release
called "selfapp" gives selfapp-app, selfapp-mysql, selfapp-web...
*/}}
{{- define "selfapp.fullname" -}}
{{- .Release.Name -}}
{{- end -}}

{{/*
Labels added to every resource (Kubernetes' recommended label set).
*/}}
{{- define "selfapp.labels" -}}
app.kubernetes.io/name: {{ include "selfapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
