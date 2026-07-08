{{/*
Expand the name of the chart.
*/}}
{{- define "gremlin-integrations.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gremlin-integrations.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gremlin-integrations.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gremlin-integrations.labels" -}}
helm.sh/chart: {{ include "gremlin-integrations.chart" . }}
{{ include "gremlin-integrations.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gremlin-integrations.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gremlin-integrations.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "gremlin-integrations.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gremlin-integrations.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Because we've evolved the recommended way to pass the secret name over time, we hide the following order of operations behind this computed value:
In later versions of this chart, we will remove the use of the fallback value of `gremlin-team-cert`
*/}}
{{- define "gremlin.secretName" -}}
{{- if .Values.gremlin.secret.managed -}}
{{- default "gremlin-integrations-secret" .Values.gremlin.secret.name -}}
{{- else -}}
{{- default "gremlin-integrations-team-cert" .Values.gremlin.secret.name -}}
{{- end -}}
{{- end -}}

{{- define "gremlinServiceUrl" -}}
{{- if .Values.gremlin.serviceUrl -}}
{{- .Values.gremlin.serviceUrl -}}
{{- else -}}
{{- "https://api.gremlin.com/v1" -}}
{{- end -}}
{{- end -}}

{{/*
Create a computed value for the intended Gremlin secret type which can either be `certificate` or `secret`
*/}}
{{- define "gremlin.secretType" -}}
{{- if .Values.gremlin.secret.type -}}
{{- .Values.gremlin.secret.type -}}
{{- else -}}
{{- if .Values.gremlin.secret.managed -}}
{{- if .Values.gremlin.secret.teamSecret -}}
{{- "secret" -}}
{{- else -}}
{{- "certificate" -}}
{{- end -}}
{{- else -}}
{{- "certificate" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "gremlin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gremlin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
gremlinTlsIdentityValidate fails if more than one identity strategy is fully configured for gremlin
*/}}
{{- define "gremlinTlsIdentityValidate" -}}
{{- $remoteSecret := and .Values.gremlin.tls.identity.remoteSecret.cert .Values.gremlin.tls.identity.remoteSecret.key -}}
{{- $createSecret := and .Values.gremlin.tls.identity.createSecret.name .Values.gremlin.tls.identity.createSecret.cert .Values.gremlin.tls.identity.createSecret.key -}}
{{- $existingSecret := and .Values.gremlin.tls.identity.existingSecret.name .Values.gremlin.tls.identity.existingSecret.cert .Values.gremlin.tls.identity.existingSecret.key -}}
{{- $count := 0 -}}
{{- if $remoteSecret }}{{- $count = add $count 1 -}}{{- end -}}
{{- if $createSecret }}{{- $count = add $count 1 -}}{{- end -}}
{{- if $existingSecret }}{{- $count = add $count 1 -}}{{- end -}}
{{- if gt (int $count) 1 -}}
{{- fail "gremlin.tls.identity: only one of remoteSecret, createSecret, or existingSecret should be fully configured" -}}
{{- end -}}
{{- end -}}

{{/*
gremlinTlsIdentityEnv returns the environment variables needed to configure TLS client identity
When remoteSecret is configured
  - sets GREMLIN_TLS_IDENTITY_CERTIFICATE and GREMLIN_TLS_IDENTITY_PRIVATE_KEY to their respective `cert` and `key` values
When createSecret or existingSecret are configured
  - sets GREMLIN_TLS_IDENTITY_CERTIFICATE and GREMLIN_TLS_IDENTITY_PRIVATE_KEY to their respective file paths, mounted by gremlinTlsIdentityVolumeMounts
*/}}
{{- define "gremlinTlsIdentityEnv" -}}
{{- if .Values.gremlin.tls.identity.enabled -}}
{{- include "gremlinTlsIdentityValidate" . -}}
{{- if and .Values.gremlin.tls.identity.remoteSecret.cert .Values.gremlin.tls.identity.remoteSecret.key -}}
- name: GREMLIN_TLS_IDENTITY_CERTIFICATE
  value: {{ .Values.gremlin.tls.identity.remoteSecret.cert | quote }}
- name: GREMLIN_TLS_IDENTITY_PRIVATE_KEY
  value: {{ .Values.gremlin.tls.identity.remoteSecret.key | quote }}
{{- else if and .Values.gremlin.tls.identity.createSecret.name .Values.gremlin.tls.identity.createSecret.cert .Values.gremlin.tls.identity.createSecret.key -}}
- name: GREMLIN_TLS_IDENTITY_CERTIFICATE
  value: /var/lib/gremlin/tls/identity/cert
- name: GREMLIN_TLS_IDENTITY_PRIVATE_KEY
  value: /var/lib/gremlin/tls/identity/key
{{- else if .Values.gremlin.tls.identity.existingSecret.name -}}
- name: GREMLIN_TLS_IDENTITY_CERTIFICATE
  value: /var/lib/gremlin/tls/identity/{{ .Values.gremlin.tls.identity.existingSecret.cert }}
- name: GREMLIN_TLS_IDENTITY_PRIVATE_KEY
  value: /var/lib/gremlin/tls/identity/{{ .Values.gremlin.tls.identity.existingSecret.key }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
gremlinTlsIdentityVolumeMounts returns the mounts needed to access TLS client identity files
When createSecret or existingSecret are configured
  - mounts to designated secret files under /var/lib/gremlin/tls/identity
*/}}
{{- define "gremlinTlsIdentityVolumeMounts" -}}
{{- if .Values.gremlin.tls.identity.enabled -}}
{{- include "gremlinTlsIdentityValidate" . -}}
{{- if and .Values.gremlin.tls.identity.createSecret.name .Values.gremlin.tls.identity.createSecret.cert .Values.gremlin.tls.identity.createSecret.key -}}
- name: gremlin-tls-identity
  mountPath: /var/lib/gremlin/tls/identity
  readOnly: true
{{- else if .Values.gremlin.tls.identity.existingSecret.name -}}
- name: gremlin-tls-identity
  mountPath: /var/lib/gremlin/tls/identity
  readOnly: true
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
gremlinTlsIdentityVolumes returns the volumes that contain TLS client identity files
When createSecret or existingSecret are configured
  - defines the volume associated with the designated secret
*/}}
{{- define "gremlinTlsIdentityVolumes" -}}
{{- if .Values.gremlin.tls.identity.enabled -}}
{{- include "gremlinTlsIdentityValidate" . -}}
{{- if and .Values.gremlin.tls.identity.createSecret.name .Values.gremlin.tls.identity.createSecret.cert .Values.gremlin.tls.identity.createSecret.key -}}
- name: gremlin-tls-identity
  secret:
    secretName: {{ .Values.gremlin.tls.identity.createSecret.name }}
{{- else if .Values.gremlin.tls.identity.existingSecret.name -}}
- name: gremlin-tls-identity
  secret:
    secretName: {{ .Values.gremlin.tls.identity.existingSecret.name }}
{{- end -}}
{{- end -}}
{{- end -}}
