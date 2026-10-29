{{/*
Compile all problems into a single message, and call fail.
*/}}
{{- define "gremlin-operator.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.names" .) -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.installNamespace" .) -}}
{{- $messages = append $messages (include "gremlin-operator.validateValues.credentialNamespaces" .) -}}
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
The longest object name the chart renders is a Service, <prefix>-credential-manager-metrics-service, which has to fit
in 63 characters.
*/}}
{{- define "gremlin-operator.validateValues.names" -}}
{{- $prefix := include "gremlin-operator.prefix" . -}}
{{- if gt (len $prefix) 28 -}}
- fullnameOverride and nameOverride: the object name prefix "{{ $prefix }}" is {{ len $prefix }} characters, but at most 28 fit in the longest Service name.
{{- end -}}
{{- end -}}

{{- define "gremlin-operator.validateValues.installNamespace" -}}
{{- $ns := toString .Values.installNamespace.name -}}
{{- if eq $ns "" -}}
- installNamespace.name must not be empty.
{{- else if not (and (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $ns) (le (len $ns) 63)) -}}
- installNamespace.name {{ $ns | quote }} is not a valid namespace name (a DNS-1123 label of at most 63 characters).
{{- else if eq $ns "gremlin-system" -}}
- installNamespace.name must not be gremlin-system, the credential namespace; the operator processes refuse to start with it.
{{- else if eq $ns .Release.Namespace -}}
- installNamespace.name {{ $ns | quote }} is the release namespace; the operator processes refuse to start with their own namespace as the install namespace.
{{- end -}}
{{- end -}}

{{- define "gremlin-operator.validateValues.credentialNamespaces" -}}
{{- $list := .Values.credentialNamespaces -}}
{{- if not (kindIs "slice" $list) -}}
- credentialNamespaces must be a list of namespace names.
{{- else -}}
{{- $errors := list -}}
{{- $seen := list -}}
{{- range $i, $entry := $list -}}
{{- $ns := toString $entry -}}
{{- if or (kindIs "invalid" $entry) (eq $ns "") -}}
{{- $errors = append $errors (printf "- credentialNamespaces[%d] must not be empty." $i) -}}
{{- else if not (and (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $ns) (le (len $ns) 63)) -}}
{{- $errors = append $errors (printf "- credentialNamespaces[%d] %q is not a valid namespace name (a DNS-1123 label of at most 63 characters)." $i $ns) -}}
{{- else if has $ns $seen -}}
{{- $errors = append $errors (printf "- credentialNamespaces[%d] %q is listed more than once." $i $ns) -}}
{{- else if eq $ns $.Release.Namespace -}}
{{- $errors = append $errors (printf "- credentialNamespaces[%d] %q is the release namespace; a credential namespace holds only team-certificate Secrets and the release's own Secrets live in the release namespace." $i $ns) -}}
{{- end -}}
{{- $seen = append $seen $ns -}}
{{- end -}}
{{- if and $list (not (has (toString $.Values.installNamespace.name) $seen)) -}}
{{- $errors = append $errors (printf "- credentialNamespaces must list installNamespace.name %q when it is not empty, or the Agent reports InstallNamespaceNotWatched." (toString $.Values.installNamespace.name)) -}}
{{- end -}}
{{- join "\n" $errors -}}
{{- end -}}
{{- end -}}

{{/*
Helm stores its release Secrets in the release namespace, and the credential namespace is dedicated to Secrets of
team certificates.
*/}}
{{- define "gremlin-operator.validateValues.releaseNamespace" -}}
{{- if eq .Release.Namespace "gremlin-system" -}}
- the release namespace (--namespace) is gremlin-system, the credential namespace; install the chart into its own namespace such as gremlin-operator-system.
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
