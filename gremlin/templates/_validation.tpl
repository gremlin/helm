{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "gremlin.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "gremlin.validateValues.secret" .) -}}
{{- $messages := append $messages (include "gremlin.validateValues.chaoDynamicQuery" .) -}}
{{- $messages := append $messages (include "gremlin.validateValues.chaoDynamicQueryVerbs" .) -}}
{{- $messages := append $messages (include "gremlin.validateValues.chaoDynamicQueryDenylist" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{- printf "%s" $message | fail -}}
{{- else -}}
{{- printf "Validation succeeded." -}}
{{- end -}}
{{- end -}}

{{- define "gremlin.validateValues.secret" -}}
{{- if and .Values.gremlin.secret.managed (eq .Values.gremlin.secret.type "certificate") (or (not .Values.gremlin.secret.certificate) (not .Values.gremlin.secret.key)) -}}
- When using a managed certificate, both the certificate and key must be provided.
{{- end -}}
{{- end -}}

{{- define "gremlin.validateValues.chaoDynamicQueryVerbs" -}}
{{- if .Values.chao.features.dynamicQuery.enabled -}}
{{- $readOnly := list "get" "list" -}}
{{- $rejected := list -}}
{{- range $entry := default (list) .Values.chao.features.dynamicQuery.allowlist -}}
{{- range $verb := default (list) $entry.verbs -}}
{{- if not (has $verb $readOnly) -}}
{{- $rejected = append $rejected $verb -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $rejected -}}
- chao.features.dynamicQuery.allowlist grants only the read-only verbs get and list, but found: {{ join ", " (uniq $rejected) }}.
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
The allowlist is the whole of what chao may read, so it has to say so exactly. An entry that omits its apiGroups is
rejected rather than defaulted to every group, an entry that omits its resources is rejected rather than rendered as
a rule granting nothing, and an enabled feature naming no resources at all is rejected rather than deploying a chao
that cannot query anything.
*/}}
{{- define "gremlin.validateValues.chaoDynamicQuery" -}}
{{- if .Values.chao.features.dynamicQuery.enabled -}}
{{- $errors := list -}}
{{- $resources := list -}}
{{- range $entry := default (list) .Values.chao.features.dynamicQuery.allowlist -}}
{{- $resources = concat $resources (default (list) $entry.resources) -}}
{{- if not $entry.resources -}}
{{- $errors = append $errors (printf "- chao.features.dynamicQuery.allowlist entry for apiGroups %s does not name its resources. Name them explicitly." (toJson (default (list) $entry.apiGroups))) -}}
{{- end -}}
{{- if not $entry.apiGroups -}}
{{- $errors = append $errors (printf "- chao.features.dynamicQuery.allowlist entry for resources %s does not name its apiGroups. Name them explicitly; the core API group is the empty string (\"\")." (toJson (default (list) $entry.resources))) -}}
{{- end -}}
{{- end -}}
{{- if not $resources -}}
{{- $errors = append $errors "- chao.features.dynamicQuery is enabled but its allowlist names no resources. List the resources Gremlin should be able to query, or disable the feature." -}}
{{- end -}}
{{- join "\n" (uniq $errors) -}}
{{- end -}}
{{- end -}}

{{/*
The denylist is joined into a single comma-separated -deny_resources flag, so an entry carrying its own comma or a
stray space would silently become something other than what was written.
*/}}
{{- define "gremlin.validateValues.chaoDynamicQueryDenylist" -}}
{{- if .Values.chao.features.dynamicQuery.enabled -}}
{{- $rejected := list -}}
{{- range $entry := default (list) .Values.chao.features.dynamicQuery.denylist -}}
{{- $entry = toString $entry -}}
{{- if or (eq $entry "") (contains "," $entry) (ne $entry (nospace $entry)) -}}
{{- $rejected = append $rejected (toJson $entry) -}}
{{- end -}}
{{- end -}}
{{- if $rejected -}}
- chao.features.dynamicQuery.denylist entries are joined into one -deny_resources flag, so each must name a single resource as resource.group or *.group, with no commas or spaces. Found: {{ join ", " (uniq $rejected) }}.
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Reserved volume names the Gremlin DaemonSet itself manages, one per line (flush left -- no leading
whitespace, no comment lines; splitList "\n" turns a leading/trailing blank into an empty entry
that never matches a real name, but keep entries flush left anyway since indentation would
otherwise become part of the name). Includes the container-driver socket volumes, derived from
.Values.containerDrivers.*.name rather than hardcoded, so a renamed driver stays covered. Callers
turn this into a list with splitList "\n" (include "gremlin.reservedNames.daemonsetVolumes" .).
Keeping this in one named template means there is exactly one place to edit when a new
chart-managed volume name appears.
*/}}
{{- define "gremlin.reservedNames.daemonsetVolumes" -}}
gremlin-state
gremlin-executions
gremlin-logs
cgroup-root
seccomp-root
seccomp-profile
gremlin-cert
ssl-cert-file
gremlin-tls-identity
gremlin-opencl-icd
kfd
dri
opencl-vendors
{{- range $key, $val := .Values.containerDrivers }}
{{ $val.name }}-sock
{{- end }}
{{- end -}}

{{/*
Reserved container names the Gremlin DaemonSet itself manages, one per line. See
gremlin.reservedNames.daemonsetVolumes for the calling convention and formatting rules.
*/}}
{{- define "gremlin.reservedNames.daemonsetContainers" -}}
seccomp-init
gremlin
{{- end -}}

{{/*
Reserved volume names the Chao deployment itself manages, one per line. Deliberately a separate,
narrower list from the DaemonSet's -- Chao renders only gremlin-cert (unconditional),
ssl-cert-file (when ssl.certFile is set), and chao-tls-identity (when chao.tls.identity is
configured); reusing the DaemonSet's list here would reject chao.extraVolumes/extraVolumeMounts
entries that don't actually collide with anything Chao renders.
*/}}
{{- define "gremlin.reservedNames.chaoVolumes" -}}
gremlin-cert
ssl-cert-file
chao-tls-identity
{{- end -}}

{{/*
Reserved container names the Chao deployment itself manages, one per line. Chao's pod has a single
container (chao) and no chart-managed init container, unlike the DaemonSet's seccomp-init.
*/}}
{{- define "gremlin.reservedNames.chaoContainers" -}}
chao
{{- end -}}

{{/*
Generic reserved-name collision check. Takes dict "entries" <list> "reserved" <list> "valuePath"
<string> "kind" <string>, and fails on the first entry whose .name is in the reserved list. An
entry with no name field does not match and is left to the Kubernetes API to reject.
*/}}
{{- define "gremlin.validateReservedNames.check" -}}
{{- range $entry := .entries -}}
{{- if $entry.name -}}
{{- if has $entry.name $.reserved -}}
{{- fail (printf "%s: %q collides with a %s name the gremlin chart manages. Rename it." $.valuePath $entry.name $.kind) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Reserved-name collision checks for the Gremlin DaemonSet's user-supplied initContainers,
extraVolumes, and extraVolumeMounts. Calls fail directly rather than contributing to
gremlin.validateValues's aggregate message, so it also fires when a single template
(daemonset.yaml) is rendered on its own.
*/}}
{{- define "gremlin.validateReservedNames.daemonset" -}}
{{- $volumes := splitList "\n" (include "gremlin.reservedNames.daemonsetVolumes" .) -}}
{{- $containers := splitList "\n" (include "gremlin.reservedNames.daemonsetContainers" .) -}}
{{- include "gremlin.validateReservedNames.check" (dict "entries" .Values.initContainers "reserved" $containers "valuePath" "initContainers" "kind" "container") -}}
{{- include "gremlin.validateReservedNames.check" (dict "entries" .Values.extraVolumes "reserved" $volumes "valuePath" "extraVolumes" "kind" "volume") -}}
{{- include "gremlin.validateReservedNames.check" (dict "entries" .Values.extraVolumeMounts "reserved" $volumes "valuePath" "extraVolumeMounts" "kind" "volume") -}}
{{- end -}}

{{/*
Reserved-name collision checks for the Chao deployment's user-supplied initContainers,
extraVolumes, and extraVolumeMounts. See gremlin.validateReservedNames.daemonset.
*/}}
{{- define "gremlin.validateReservedNames.chao" -}}
{{- $volumes := splitList "\n" (include "gremlin.reservedNames.chaoVolumes" .) -}}
{{- $containers := splitList "\n" (include "gremlin.reservedNames.chaoContainers" .) -}}
{{- include "gremlin.validateReservedNames.check" (dict "entries" .Values.chao.initContainers "reserved" $containers "valuePath" "chao.initContainers" "kind" "container") -}}
{{- include "gremlin.validateReservedNames.check" (dict "entries" .Values.chao.extraVolumes "reserved" $volumes "valuePath" "chao.extraVolumes" "kind" "volume") -}}
{{- include "gremlin.validateReservedNames.check" (dict "entries" .Values.chao.extraVolumeMounts "reserved" $volumes "valuePath" "chao.extraVolumeMounts" "kind" "volume") -}}
{{- end -}}
