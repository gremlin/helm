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
In later versions of this chart, we will remove the use of the fallback value of `gremlin-team-cert`
*/}}
{{- define "gremlin.secretName" -}}
{{- if .Values.gremlin.secret.managed -}}
{{- default "gremlin-secret" .Values.gremlin.secret.name -}}
{{- else -}}
{{- default "gremlin-team-cert" .Values.gremlin.secret.name -}}
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

{{- define "containerDriverWithDefaultOrError" -}}
{{- if .Values.gremlin.container.driver -}}
{{- $valid := list "any" "docker-linux" "containerd-linux" "crio-linux" "linux" -}}
{{- if has .Values.gremlin.container.driver $valid -}}
{{- .Values.gremlin.container.driver -}}
{{- else -}}
{{- fail (printf "unknown container driver: %s (must be one of %s)" .Values.gremlin.container.driver (join ", " $valid)) -}}
{{- end -}}
{{- else -}}
{{- "docker-linux" -}}
{{- end -}}
{{- end -}}

{{- define "containerMounts" -}}
{{- $selectedDriver := (include "containerDriverWithDefaultOrError" .) -}}
{{- $mountPaths := (dict "docker-linux" (dict "name" "docker" "socket" "/var/run/docker.sock") "containerd-linux" (dict "name" "containerd" "socket" "/run/containerd/containerd.sock") "crio-linux" (dict "name" "crio" "socket" "/run/crio/crio.sock")) -}}
{{- $validDrivers := keys .Values.containerDrivers -}}
{{- $validDrivers = append $validDrivers "linux" -}}
{{- $validDrivers = append $validDrivers "any" -}}
{{- if has $selectedDriver $validDrivers -}}
{{- range $key, $val := .Values.containerDrivers -}}
{{- if and (or (eq $key $selectedDriver) (or (eq $selectedDriver "linux") (eq $selectedDriver "any"))) ($val.runtimeSocket) }}
- name: {{ $val.name }}-sock
  mountPath: {{ (get $mountPaths $key).socket }}
  readOnly: true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "containerMountsPSP" -}}
{{- $selectedDriver := (include "containerDriverWithDefaultOrError" .) -}}
{{- $mountPaths := (dict "docker-linux" (dict "name" "docker" "socket" "/var/run/docker.sock") "containerd-linux" (dict "name" "containerd" "socket" "/run/containerd/containerd.sock") "crio-linux" (dict "name" "crio" "socket" "/run/crio/crio.sock")) -}}
{{- $validDrivers := keys .Values.containerDrivers -}}
{{- $validDrivers = append $validDrivers "linux" -}}
{{- $validDrivers = append $validDrivers "any" -}}
{{- if has $selectedDriver $validDrivers -}}
{{- range $key, $val := .Values.containerDrivers -}}
{{- if and (or (eq $key $selectedDriver) (or (eq $selectedDriver "linux") (eq $selectedDriver "any"))) ($val.runtimeSocket) }}
- pathPrefix: {{ (get $mountPaths $key).socket }}
  readOnly: true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "containerVolumes" -}}
{{- $selectedDriver := (include "containerDriverWithDefaultOrError" .) -}}
{{- $validDrivers := keys .Values.containerDrivers -}}
{{- $validDrivers = append $validDrivers "linux" -}}
{{- $validDrivers = append $validDrivers "any" -}}
{{- if has $selectedDriver $validDrivers -}}
{{- range $key, $val := .Values.containerDrivers -}}
{{- if and (or (eq $key $selectedDriver) (or (eq $selectedDriver "linux") (eq $selectedDriver "any"))) ($val.runtimeSocket) }}
- name: {{ $val.name }}-sock
  hostPath:
    path: {{ $val.runtimeSocket }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* GKE Container Optimized OS with Containerd cannot */ -}}
{{- /* mount the state/logs volumes, so detect that here */ -}}
{{- define "gkeCOSContainerd" -}}
{{- $output := false }}
{{- range $index, $node := (lookup "v1" "Node" "" "").items -}}
  {{- $gkeRuntime := index $node.metadata.labels "cloud.google.com/gke-container-runtime" -}}
  {{- $gkeOS := index $node.metadata.labels "cloud.google.com/gke-os-distribution" -}}
  {{- $output = (or $output (and (eq $gkeRuntime "containerd") (eq $gkeOS "cos"))) -}}
{{- end -}}
{{ $output }}
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
