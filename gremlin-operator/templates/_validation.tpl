{{/*
Compile all problems into a single message, and call fail.
*/}}
{{- define "gremlin-operator.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.names" .) -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.installNamespace" .) -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.releaseNamespace" .) -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.process" (dict "path" "reconciler" "process" .Values.reconciler)) -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.process" (dict "path" "credentialManager" "process" .Values.credentialManager)) -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.switches" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{- printf "%s" $message | fail -}}
{{- else -}}
{{- printf "Validation succeeded." -}}
{{- end -}}
{{- end -}}

{{/*
Names the operator and its documentation reserve for the system. Returns "yes" for default, kube-* and openshift-*.
*/}}
{{- define "gremlin-operator.systemNamespace" -}}
{{- if or (eq . "default") (hasPrefix "kube-" .) (hasPrefix "openshift-" .) -}}yes{{- end -}}
{{- end -}}

{{/*
nameOverride and fullnameOverride end up in object names and labels. The longest object name the chart renders is a
Service, <prefix>-credential-manager-metrics-service, which has to fit in 63 characters.
*/}}
{{- define "gremlin-operator.validateValues.names" -}}
{{- $errors := list -}}
{{- range $path := list "nameOverride" "fullnameOverride" -}}
{{- $value := toString (default "" (get $.Values $path)) -}}
{{- if and (ne $value "") (not (and (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $value) (le (len $value) 63))) -}}
{{- $errors = append $errors (printf "- %s %q is not a valid name (a DNS-1123 label of at most 63 characters)." $path $value) -}}
{{- end -}}
{{- end -}}
{{- $prefix := include "gremlin-operator.prefix" . -}}
{{- if gt (len $prefix) 28 -}}
{{- $errors = append $errors (printf "- fullnameOverride and nameOverride: the object name prefix %q is %d characters, but at most 28 fit in the longest Service name." $prefix (len $prefix)) -}}
{{- end -}}
{{- join "\n" $errors -}}
{{- end -}}

{{- define "gremlin-operator.validateValues.installNamespace" -}}
{{- $ns := toString .Values.installNamespace.name -}}
{{- if eq $ns "" -}}
- installNamespace.name must not be empty.
{{- else if not (and (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $ns) (le (len $ns) 63)) -}}
- installNamespace.name {{ $ns | quote }} is not a valid namespace name (a DNS-1123 label of at most 63 characters).
{{- else if eq $ns .Release.Namespace -}}
- installNamespace.name {{ $ns | quote }} is the release namespace; the operator processes refuse to start with their own namespace as the install namespace.
{{- else if include "gremlin-operator.systemNamespace" $ns -}}
- installNamespace.name {{ $ns | quote }} is a system namespace. Use a new namespace: the credential manager gets write access to Secrets in the install namespace and the reconciler can create workloads there, so it must not be default, kube-* or openshift-*.
{{- end -}}
{{- end -}}

{{- define "gremlin-operator.validateValues.releaseNamespace" -}}
{{- if include "gremlin-operator.systemNamespace" .Release.Namespace -}}
- the release namespace (--namespace) {{ .Release.Namespace | quote }} is a system namespace. The credential manager's ServiceAccount lives there and can read every Secret in the cluster, so anyone who can create workloads, exec into pods or mint tokens in it holds those Secrets. Install into a dedicated namespace such as gremlin-system.
{{- end -}}
{{- end -}}

{{/*
Takes a dict with path (reconciler or credentialManager) and process (that block of the values).
*/}}
{{- define "gremlin-operator.validateValues.process" -}}
{{- $errors := list -}}
{{- $resync := ternary "" (toString .process.resyncInterval) (kindIs "invalid" .process.resyncInterval) -}}
{{- if and (ne $resync "") (not (and (regexMatch "^([0-9]+(\\.[0-9]+)?(ns|us|µs|μs|ms|s|m|h))+$" $resync) (regexMatch "[1-9]" $resync))) -}}
{{- $errors = append $errors (printf "- %s.resyncInterval %q is not a positive duration such as 30s or 1h30m." .path $resync) -}}
{{- end -}}
{{- $level := ternary "" (toString .process.logLevel) (kindIs "invalid" .process.logLevel) -}}
{{- if and (ne $level "") (not (or (regexMatch "(?i)^(debug|info|error|panic)$" $level) (and (regexMatch "^[0-9]+$" $level) (regexMatch "[1-9]" $level)))) -}}
{{- $errors = append $errors (printf "- %s.logLevel %q is not one of debug, info, error, panic or a positive integer." .path $level) -}}
{{- end -}}
{{- join "\n" $errors -}}
{{- end -}}

{{- define "gremlin-operator.validateValues.switches" -}}
{{- $errors := list -}}
{{- if not (kindIs "bool" .Values.agent.nodeRead.enabled) -}}
{{- $errors = append $errors (printf "- agent.nodeRead.enabled must be true or false, but is %s." (toJson .Values.agent.nodeRead.enabled)) -}}
{{- end -}}
{{- if not (kindIs "bool" .Values.openshift.enabled) -}}
{{- $errors = append $errors (printf "- openshift.enabled must be true or false, but is %s." (toJson .Values.openshift.enabled)) -}}
{{- end -}}
{{- join "\n" $errors -}}
{{- end -}}
