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
chaoTlsIdentityValidate fails if more than one identity strategy is fully configured for chao
*/}}
{{- define "chaoTlsIdentityValidate" -}}
{{- $remoteSecret := and .Values.chao.tls.identity.remoteSecret.cert .Values.chao.tls.identity.remoteSecret.key -}}
{{- $createSecret := and .Values.chao.tls.identity.createSecret.name .Values.chao.tls.identity.createSecret.cert .Values.chao.tls.identity.createSecret.key -}}
{{- $existingSecret := and .Values.chao.tls.identity.existingSecret.name .Values.chao.tls.identity.existingSecret.cert .Values.chao.tls.identity.existingSecret.key -}}
{{- $count := 0 -}}
{{- if $remoteSecret }}{{- $count = add $count 1 -}}{{- end -}}
{{- if $createSecret }}{{- $count = add $count 1 -}}{{- end -}}
{{- if $existingSecret }}{{- $count = add $count 1 -}}{{- end -}}
{{- if gt (int $count) 1 -}}
{{- fail "chao.tls.identity: only one of remoteSecret, createSecret, or existingSecret should be fully configured" -}}
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

{{/*
chaoTlsIdentityArgs returns the chao cli arguments needed to configure TLS client identity
When remoteSecret is configured
  - sets -tls_identity_cert and -tls_identity_private_key to their respective `cert` and `key` values
When createSecret or existingSecret are configured
  - sets -tls_identity_cert and -tls_identity_private_key to their respective file paths, mounted by chaoTlsIdentityVolumeMounts
*/}}
{{- define "chaoTlsIdentityArgs" -}}
{{- if .Values.chao.tls.identity.enabled -}}
{{- include "chaoTlsIdentityValidate" . -}}
{{- if and .Values.chao.tls.identity.remoteSecret.cert .Values.chao.tls.identity.remoteSecret.key -}}
- "-tls_identity_cert"
- {{ .Values.chao.tls.identity.remoteSecret.cert | quote }}
- "-tls_identity_key"
- {{ .Values.chao.tls.identity.remoteSecret.key | quote }}
{{- else if and .Values.chao.tls.identity.createSecret.name .Values.chao.tls.identity.createSecret.cert .Values.chao.tls.identity.createSecret.key -}}
- "-tls_identity_cert"
- "/var/lib/gremlin/tls/identity/cert"
- "-tls_identity_key"
- "/var/lib/gremlin/tls/identity/key"
{{- else if .Values.chao.tls.identity.existingSecret.name -}}
- "-tls_identity_cert"
- "/var/lib/gremlin/tls/identity/{{ .Values.chao.tls.identity.existingSecret.cert }}"
- "-tls_identity_key"
- "/var/lib/gremlin/tls/identity/{{ .Values.chao.tls.identity.existingSecret.key }}"
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
chaoTlsIdentityVolumes returns the volumes that contain TLS client identity files
When createSecret or existingSecret are configured
  - defines the volume associated with the designated secret
*/}}
{{- define "chaoTlsIdentityVolumeMounts" -}}
{{- if .Values.chao.tls.identity.enabled -}}
{{- include "chaoTlsIdentityValidate" . -}}
{{- if and .Values.chao.tls.identity.createSecret.name .Values.chao.tls.identity.createSecret.cert .Values.chao.tls.identity.createSecret.key -}}
- name: chao-tls-identity
  mountPath: /var/lib/gremlin/tls/identity
  readOnly: true
{{- else if .Values.chao.tls.identity.existingSecret.name -}}
- name: chao-tls-identity
  mountPath: /var/lib/gremlin/tls/identity
  readOnly: true
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
chaoTlsIdentityVolumes returns the volumes that contain TLS client identity files
When createSecret or existingSecret are configured
  - defines the volume associated with the designated secret
*/}}
{{- define "chaoTlsIdentityVolumes" -}}
{{- if .Values.chao.tls.identity.enabled -}}
{{- include "chaoTlsIdentityValidate" . -}}
{{- if and .Values.chao.tls.identity.createSecret.name .Values.chao.tls.identity.createSecret.cert .Values.chao.tls.identity.createSecret.key -}}
- name: chao-tls-identity
  secret:
    secretName: {{ .Values.chao.tls.identity.createSecret.name }}
{{- else if .Values.chao.tls.identity.existingSecret.name -}}
- name: chao-tls-identity
  secret:
    secretName: {{ .Values.chao.tls.identity.existingSecret.name }}
{{- end -}}
{{- end -}}
{{- end -}}
