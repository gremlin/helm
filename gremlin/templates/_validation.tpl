{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "gremlin.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "gremlin.validateValues.secret" .) -}}
{{- $messages = without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "%s\n" $message | fail -}}
{{- else -}}
{{- printf "Validation succeeded." -}}
{{- end -}}
{{- end -}}

{{- define "gremlin.validateValues.secret" -}}
{{- if and .Values.gremlin.secret.managed (eq .Values.gremlin.secret.type "certificate") (or (not .Values.gremlin.secret.certificate) (not .Values.gremlin.secret.key)) -}}
- When using a managed certificate, both the certificate and key must be provided.
{{- end -}}
{{- end -}}
