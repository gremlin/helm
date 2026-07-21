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
gremlinGpuVendorPreset returns a YAML dict of the "easy default" GPU configuration for a
given vendor. The context passed in is the vendor string (gremlin.gpu.vendor). Supported
values are "nvidia" and "amd"; any other value (including "") yields an empty preset so the
chart falls back to whatever the advanced options specify.

  nvidia - relies on the NVIDIA container toolkit: run under the "nvidia" RuntimeClass and set
           NVIDIA_VISIBLE_DEVICES / NVIDIA_DRIVER_CAPABILITIES so the runtime injects the driver
           libraries and device nodes (no hostMounts required). Also projects the nvidia OpenCL
           ICD registry file, since some runtimes inject libnvidia-opencl.so.1 but not the
           /etc/OpenCL/vendors/nvidia.icd file the loader needs to discover it.
  amd    - relies on the ROCm/amdgpu driver on the host: mount the /dev/kfd and /dev/dri device
           nodes plus the OpenCL ICD registry so the container can reach the GPUs directly.

The optional `openclIcd` key (filename + library) tells the chart to project an OpenCL ICD
registry file; vendors that already expose /etc/OpenCL/vendors (amd) omit it.
*/}}
{{- define "gremlinGpuVendorPreset" -}}
{{- $vendor := . -}}
{{- if eq $vendor "nvidia" -}}
runtimeClassName: nvidia
env:
  - name: NVIDIA_VISIBLE_DEVICES
    value: "all"
  - name: NVIDIA_DRIVER_CAPABILITIES
    value: "all"
hostMounts: []
openclIcd:
  filename: nvidia.icd
  library: libnvidia-opencl.so.1
{{- else if eq $vendor "amd" -}}
runtimeClassName: ""
env: []
hostMounts:
  - name: kfd
    hostPath: /dev/kfd
    type: CharDevice
    readOnly: false
  - name: dri
    hostPath: /dev/dri
    type: Directory
    readOnly: false
  - name: opencl-vendors
    hostPath: /etc/OpenCL/vendors
    mountPath: /etc/OpenCL/vendors
    type: DirectoryOrCreate
    readOnly: true
{{- else -}}
runtimeClassName: ""
env: []
hostMounts: []
{{- end -}}
{{- end -}}

{{/*
gremlinGpuEffective returns a YAML dict with the effective GPU configuration: the vendor
preset (see gremlinGpuVendorPreset) with each advanced option overriding the preset when set.
A blank runtimeClassName, an empty env list, or an empty hostMounts list means "use the preset".
Keys: runtimeClassName (string), env (list), hostMounts (list), openclIcd (dict, from the preset).
*/}}
{{- define "gremlinGpuEffective" -}}
{{- $gpu := .Values.gremlin.gpu -}}
{{- $preset := fromYaml (include "gremlinGpuVendorPreset" (default "" $gpu.vendor)) -}}
{{- $runtimeClassName := $preset.runtimeClassName -}}
{{- if $gpu.runtimeClassName -}}{{- $runtimeClassName = $gpu.runtimeClassName -}}{{- end -}}
{{- $env := $preset.env -}}
{{- if $gpu.env -}}{{- $env = $gpu.env -}}{{- end -}}
{{- $hostMounts := $preset.hostMounts -}}
{{- if $gpu.hostMounts -}}{{- $hostMounts = $gpu.hostMounts -}}{{- end -}}
{{- $effective := dict "runtimeClassName" $runtimeClassName "env" $env "hostMounts" $hostMounts -}}
{{- if $preset.openclIcd -}}{{- $_ := set $effective "openclIcd" $preset.openclIcd -}}{{- end -}}
{{- $effective | toYaml -}}
{{- end -}}

{{/*
gremlinGpuRuntimeClassName returns the effective RuntimeClass name for the Gremlin pods, or
nothing when GPU access is disabled or no RuntimeClass applies.
*/}}
{{- define "gremlinGpuRuntimeClassName" -}}
{{- if .Values.gremlin.gpu.enabled -}}
{{- $eff := fromYaml (include "gremlinGpuEffective" .) -}}
{{- $eff.runtimeClassName -}}
{{- end -}}
{{- end -}}

{{/*
gremlinGpuEnv returns the environment variables that enable GPU/OpenCL access.
When gremlin.gpu.enabled is true, the effective env entries (vendor preset or the gremlin.gpu.env
override) are emitted. For the NVIDIA container toolkit these include NVIDIA_VISIBLE_DEVICES and
NVIDIA_DRIVER_CAPABILITIES (which must include `compute` or `all` for OpenCL).
*/}}
{{- define "gremlinGpuEnv" -}}
{{- if .Values.gremlin.gpu.enabled -}}
{{- $eff := fromYaml (include "gremlinGpuEffective" .) -}}
{{- with $eff.env -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
gremlinGpuOpenclIcdActive returns "true" when the chart should project an OpenCL ICD registry
file into the container, and nothing otherwise. This is the fix for NVIDIA runtimes that inject
the OpenCL driver library (libnvidia-opencl.so.1) but do NOT create /etc/OpenCL/vendors/nvidia.icd,
leaving clGetPlatformIDs with no platforms to enumerate.

The ICD is projected automatically whenever the selected vendor preset defines one (nvidia does),
UNLESS an effective hostMount already provides /etc/OpenCL/vendors (e.g. the amd preset or a custom
mount), in which case we defer to that mount to avoid overlapping mount paths.
*/}}
{{- define "gremlinGpuOpenclIcdActive" -}}
{{- if .Values.gremlin.gpu.enabled -}}
{{- $eff := fromYaml (include "gremlinGpuEffective" .) -}}
{{- if and $eff.openclIcd $eff.openclIcd.library -}}
{{- $dirMounted := false -}}
{{- range $eff.hostMounts }}
{{- if eq (default .hostPath .mountPath) "/etc/OpenCL/vendors" }}{{- $dirMounted = true -}}{{- end }}
{{- end -}}
{{- if not $dirMounted -}}true{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
gremlinGpuVolumeMounts returns the volumeMounts that expose host GPU/OpenCL drivers.
Each effective hostMounts entry (vendor preset or the gremlin.gpu.hostMounts override) becomes a
volumeMount. mountPath defaults to hostPath and readOnly defaults to true when not specified.
When gremlinGpuOpenclIcdActive, the projected OpenCL ICD file is mounted as well.
*/}}
{{- define "gremlinGpuVolumeMounts" -}}
{{- if .Values.gremlin.gpu.enabled -}}
{{- $eff := fromYaml (include "gremlinGpuEffective" .) -}}
{{- range $eff.hostMounts }}
- name: {{ .name }}
  mountPath: {{ default .hostPath .mountPath }}
  readOnly: {{ if hasKey . "readOnly" }}{{ .readOnly }}{{ else }}true{{ end }}
{{- end -}}
{{- if include "gremlinGpuOpenclIcdActive" . }}
- name: gremlin-opencl-icd
  mountPath: /etc/OpenCL/vendors/{{ $eff.openclIcd.filename }}
  subPath: {{ $eff.openclIcd.filename }}
  readOnly: true
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
gremlinGpuVolumes returns the hostPath volumes that expose host GPU/OpenCL drivers.
Each effective hostMounts entry (vendor preset or the gremlin.gpu.hostMounts override) becomes a
hostPath volume. An optional `type` (e.g. DirectoryOrCreate, CharDevice) is passed through when present.
*/}}
{{- define "gremlinGpuVolumes" -}}
{{- if .Values.gremlin.gpu.enabled -}}
{{- $eff := fromYaml (include "gremlinGpuEffective" .) -}}
{{- range $eff.hostMounts }}
- name: {{ .name }}
  hostPath:
    path: {{ .hostPath }}
    {{- if .type }}
    type: {{ .type }}
    {{- end }}
{{- end -}}
{{- if include "gremlinGpuOpenclIcdActive" . }}
- name: gremlin-opencl-icd
  configMap:
    name: {{ include "gremlin.fullname" . }}-opencl-icd
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
