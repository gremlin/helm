{{/*
Expand the name of the chart.
*/}}
{{- define "gremlin-operator.name" -}}
{{- default .Chart.Name (default "" .Values.nameOverride | toString) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
The prefix of every object name the chart owns. The release name never enters it: the operator and its documentation
refer to these objects by name, and only one operator can run in a cluster.
*/}}
{{- define "gremlin-operator.prefix" -}}
{{- default (include "gremlin-operator.name" .) (default "" .Values.fullnameOverride | toString) | trunc 63 | trimSuffix "-" }}
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
Labels on every object's metadata. Selectors are written out in each template and never use these.
*/}}
{{- define "gremlin-operator.labels" -}}
helm.sh/chart: {{ include "gremlin-operator.chart" . }}
app.kubernetes.io/name: {{ include "gremlin-operator.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
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

{{/*
Renders a map of strings as YAML with every key and value quoted, so a value such as 8443 stays a string where the API
requires one (annotations, nodeSelector).
*/}}
{{- define "gremlin-operator.stringMap" -}}
{{- range $key, $value := . -}}
{{ $key | quote }}: {{ toString $value | quote }}{{ "\n" }}
{{- end -}}
{{- end -}}
