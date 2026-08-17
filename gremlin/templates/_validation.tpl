{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "gremlin.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "gremlin.validateValues.secret" .) -}}
{{- $messages := append $messages (include "gremlin.validateValues.chaoDynamicQuery" .) -}}
{{- $messages := append $messages (include "gremlin.validateValues.chaoDynamicQueryVerbs" .) -}}
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
rejected rather than defaulted to every group, and an enabled feature naming no resources at all is rejected rather
than deploying a chao that cannot query anything.
*/}}
{{- define "gremlin.validateValues.chaoDynamicQuery" -}}
{{- if .Values.chao.features.dynamicQuery.enabled -}}
{{- $errors := list -}}
{{- $resources := list -}}
{{- range $entry := default (list) .Values.chao.features.dynamicQuery.allowlist -}}
{{- $resources = concat $resources (default (list) $entry.resources) -}}
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
