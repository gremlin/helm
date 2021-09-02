{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "gremlin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gremlin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gremlin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Because we've evolved the recommended way to pass the secret name over time, we hide the following order of operations behind this computed value:
In later versions of this chart, we will remove the use of `.Values.gremlin.client.secretName` and the fallback value of `gremlin-team-cert`
*/}}
{{- define "gremlin.secretName" -}}
{{- if .Values.gremlin.secret.managed -}}
{{- default .Values.gremlin.client.secretName .Values.gremlin.secret.name | default "gremlin-secret" -}}
{{- else -}}
{{- default .Values.gremlin.client.secretName .Values.gremlin.secret.name | default "gremlin-team-cert" -}}
{{- end -}}
{{- end -}}

{{/*
Create a computed value for the intended Gremlin secret type which can either be `certificate` or `secret`
*/}}
{{- define "gremlin.secretType" -}}
{{- if .Values.gremlin.secret.type -}}
{{- .Values.gremlin.secret.type -}}
{{- else -}}
{{- if .Values.gremlin.client.certCreateSecret -}}
{{- "certificate" -}}
{{- else if .Values.gremlin.secret.managed -}}
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

{{- define "containerDriverWithDefaultOrError" -}}
{{- if .Values.gremlin.container.driver -}}
{{- $valid := list "docker" "docker-runc" "crio-runc" "containerd-runc" -}}
{{- if has .Values.gremlin.container.driver $valid -}}
{{- .Values.gremlin.container.driver -}}
{{- else -}}
{{- fail (printf "unknown container driver: %s (must be one of %s)" .Values.gremlin.container.driver (join ", " $valid)) -}}
{{- end -}}
{{- else -}}
{{- "docker" -}}
{{- end -}}
{{- end -}}

{{- define "runtimeSocket" -}}
{{- if eq "docker-runc" (include "containerDriverWithDefaultOrError" .) -}}
{{- "/var/run/docker.sock" -}}
{{- else if eq "containerd-runc" (include "containerDriverWithDefaultOrError" .) -}}
{{- "/run/containerd/containerd.sock" -}}
{{- else if eq "crio-runc" (include "containerDriverWithDefaultOrError" .) -}}
{{- "/run/crio/crio.sock" -}}
{{- else -}}
{{- "/var/run/docker.sock" -}}
{{- end -}}
{{- end -}}

{{- define "runtimeRunc" -}}
{{- if eq "docker-runc" (include "containerDriverWithDefaultOrError" .) -}}
{{- "/run/docker/runtime-runc/moby" -}}
{{- else if eq "containerd-runc" (include "containerDriverWithDefaultOrError" .) -}}
{{- "/run/containerd/runc/k8s.io" -}}
{{- else if eq "crio-runc" (include "containerDriverWithDefaultOrError" .) -}}
{{- "/run/runc" -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "pspApiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1/PodSecurityPolicy" -}}
{{- "policy/v1" -}}
{{- else -}}
{{- "policy/v1beta1" -}}
{{- end -}}
{{- end -}}

{{- define "gremlinServiceUrl" -}}
{{- if .Values.gremlin.serviceUrl -}}
{{- .Values.gremlin.serviceUrl -}}
{{- else -}}
{{- "https://api.gremlin.com/v1" -}}
{{- end -}}
{{- end -}}
