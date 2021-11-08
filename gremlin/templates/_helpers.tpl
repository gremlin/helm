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
{{- $valid := list "docker" "docker-runc" "crio-runc" "containerd-runc" "any" -}}
{{- if has .Values.gremlin.container.driver $valid -}}
{{- .Values.gremlin.container.driver -}}
{{- else -}}
{{- fail (printf "unknown container driver: %s (must be one of %s)" .Values.gremlin.container.driver (join ", " $valid)) -}}
{{- end -}}
{{- else -}}
{{- "docker" -}}
{{- end -}}
{{- end -}}

{{- define "containerMounts" -}}
{{- $selectedDriver := (include "containerDriverWithDefaultOrError" .) -}}
{{- $mountPaths := (dict "docker-runc" (dict "name" "docker" "socket" "/var/run/docker.sock" "runc" "/run/docker/runtime-runc/moby") "docker" (dict "name" "docker" "socket" "/var/run/docker.sock") "crio-runc" (dict "name" "crio" "socket" "/run/crio/crio.sock" "runc" "/run/runc") "containerd-runc" (dict "name" "containerd" "socket" "/run/containerd/containerd.sock" "runc" "/run/containerd/runc/k8s.io")) -}}
{{- range $key, $val := .Values.containerDrivers -}}
{{- /* create a list of values to match against customer selection */ -}}
{{- /* this is the current driver or all drivers in the case of "any" */ -}}
{{- /* to prevent docker from apearing twice tho, we remove any from the valid */ -}}
{{- /* list just for the key "docker" */ -}}
{{- $validDrivers := (ternary (list $key) (list $key "any") (eq $key "docker")) }}
{{- if has $selectedDriver $validDrivers -}}
{{- if $val.runtimeSocket }}
- name: {{ $val.name }}-sock
  mountPath: {{ (get $mountPaths $key).socket }}
  readOnly: true
{{- end -}}
{{- if $val.runtimeRunc }}
- name: {{ $val.name }}-runc
  mountPath: {{ (get $mountPaths $key).runc }}
  readOnly: false
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "containerMountsPSP" -}}
{{- $selectedDriver := (include "containerDriverWithDefaultOrError" .) -}}
{{- $mountPaths := (dict "docker-runc" (dict "name" "docker" "socket" "/var/run/docker.sock" "runc" "/run/docker/runtime-runc/moby") "docker" (dict "name" "docker" "socket" "/var/run/docker.sock") "crio-runc" (dict "name" "crio" "socket" "/run/crio/crio.sock" "runc" "/run/runc") "containerd-runc" (dict "name" "containerd" "socket" "/run/containerd/containerd.sock" "runc" "/run/containerd/runc/k8s.io")) -}}
{{- range $key, $val := .Values.containerDrivers -}}
{{- /* create a list of values to match against customer selection */ -}}
{{- /* this is the current driver or all drivers in the case of "any" */ -}}
{{- /* to prevent docker from apearing twice tho, we remove any from the valid */ -}}
{{- /* list just for the key "docker" */ -}}
{{- $validDrivers := (ternary (list $key) (list $key "any") (eq $key "docker")) }}
{{- if has $selectedDriver $validDrivers -}}
{{- if $val.runtimeSocket }}
- pathPrefix: {{ (get $mountPaths $key).socket }}
  readOnly: true
{{- end -}}
{{- if $val.runtimeRunc }}
- pathPrefix: {{ (get $mountPaths $key).runc }}
  readOnly: false
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "containerVolumes" -}}
{{- $selectedDriver := (include "containerDriverWithDefaultOrError" .) -}}
{{- range $key, $val := .Values.containerDrivers -}}
{{- $validDrivers := (ternary (list $key) (list $key "any") (eq $key "docker")) }}
{{- if has $selectedDriver $validDrivers -}}
{{- if $val.runtimeSocket }}
- name: {{ $val.name }}-sock
  hostPath:
    path: {{ $val.runtimeSocket }}
{{- end -}}
{{- if $val.runtimeRunc }}
- name: {{ $val.name }}-runc
  hostPath:
    path: {{ $val.runtimeRunc }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "pspApiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1/PodSecurityPolicy" -}}
{{- "policy/v1" -}}
{{- else -}}
{{- "policy/v1beta1" -}}
{{- end -}}
{{- if (and .Values.gremlin.installApparmorProfile .Values.gremlin.podSecurity.podSecurityPolicy.create )}}
{{- fail "The ApparmorInstaller is currently incompatible with PodSecurityPolicy.  If you need PodSecurityPolicies it's recommeneded you install the apparmor profile through other means and set it via gremlin.apparmor" -}}
{{- end -}}
{{- end -}}

{{- define "gremlinServiceUrl" -}}
{{- if .Values.gremlin.serviceUrl -}}
{{- .Values.gremlin.serviceUrl -}}
{{- else -}}
{{- "https://api.gremlin.com/v1" -}}
{{- end -}}
{{- end -}}
