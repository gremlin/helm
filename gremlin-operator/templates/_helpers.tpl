{{/*
Expand the name of the chart.
*/}}
{{- define "gremlin-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
The prefix of every object name the chart owns. The release name never enters it: the operator and its documentation
refer to these objects by name, and only one operator can run in a cluster.
*/}}
{{- define "gremlin-operator.prefix" -}}
{{- default (include "gremlin-operator.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gremlin-operator.reconcilerName" -}}
{{- printf "%s-controller-manager" (include "gremlin-operator.prefix" .) }}
{{- end }}

{{- define "gremlin-operator.credentialManagerName" -}}
{{- printf "%s-credential-manager" (include "gremlin-operator.prefix" .) }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gremlin-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels on every object's metadata. Selectors use gremlin-operator.selectorLabels, never these.
*/}}
{{- define "gremlin-operator.labels" -}}
helm.sh/chart: {{ include "gremlin-operator.chart" . }}
app.kubernetes.io/name: {{ include "gremlin-operator.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
The one image both processes run; the command picks the process.
*/}}
{{- define "gremlin-operator.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag | toString) }}
{{- end }}
