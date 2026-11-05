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
Names the operator and its documentation reserve for the system. Returns "yes" for default, openshift, kube-* and openshift-*.
*/}}
{{- define "gremlin-operator.systemNamespace" -}}
{{- if or (eq . "default") (eq . "openshift") (hasPrefix "kube-" .) (hasPrefix "openshift-" .) -}}yes{{- end -}}
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
{{- if not (regexMatch "^[a-z]" $prefix) -}}
{{- $errors = append $errors (printf "- fullnameOverride and nameOverride: the object name prefix %q must start with a lowercase letter, because Service names must." $prefix) -}}
{{- end -}}
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
{{- $prefix := include "gremlin-operator.prefix" . -}}
{{- range $old := list (dict "kind" "Role" "name" (printf "%s-credential-manager-role" $prefix)) (dict "kind" "RoleBinding" "name" (printf "%s-credential-manager-rolebinding" $prefix)) -}}
{{- if lookup "rbac.authorization.k8s.io/v1" $old.kind $.Release.Namespace $old.name }}
- the release namespace {{ $.Release.Namespace | quote }} still holds the {{ $old.kind }} {{ $old.name | quote }} that an older operator layout granted the credential manager there. Delete it before installing: it gives Secret write in this namespace to a ServiceAccount of another namespace.
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Takes a dict with path (reconciler or credentialManager) and process (that block of the values).
*/}}
{{- define "gremlin-operator.validateValues.process" -}}
{{- $errors := list -}}
{{- if not (regexMatch "^[0-9]+$" (toString .process.replicas)) -}}
{{- $errors = append $errors (printf "- %s.replicas must be a whole number of 0 or more, but is %s." .path (toJson .process.replicas)) -}}
{{- end -}}
{{- $resync := ternary "" (toString .process.resyncInterval) (kindIs "invalid" .process.resyncInterval) -}}
{{- if and (ne $resync "") (not (and (regexMatch "^\\+?(([0-9]+(\\.[0-9]*)?|\\.[0-9]+)(ns|us|µs|μs|ms|s|m|h))+$" $resync) (regexMatch "[1-9]" $resync))) -}}
{{- $errors = append $errors (printf "- %s.resyncInterval %q is not a positive duration such as 30s or 1h30m." .path $resync) -}}
{{- end -}}
{{- if and (ne $resync "") (regexMatch "^\\+?(([0-9]+(\\.[0-9]*)?|\\.[0-9]+)(ns|us|µs|μs|ms|s|m|h))+$" $resync) -}}
{{- $units := dict "ns" 1.0 "us" 1000.0 "µs" 1000.0 "μs" 1000.0 "ms" 1000000.0 "s" 1000000000.0 "m" 60000000000.0 "h" 3600000000000.0 -}}
{{- $total := 0.0 -}}
{{- range $part := regexFindAll "([0-9]+(\\.[0-9]*)?|\\.[0-9]+)(ns|us|µs|μs|ms|s|m|h)" $resync -1 -}}
{{- $total = addf $total (mulf (float64 (regexFind "^[0-9.]+" $part)) (get $units (regexFind "[a-zµμ]+$" $part))) -}}
{{- end -}}
{{- if or (lt $total 1.0) (ge $total 9223372036854775807.0) -}}
{{- $errors = append $errors (printf "- %s.resyncInterval %q is outside what the operator accepts: at least 1ns and below about 2562047h." $.path $resync) -}}
{{- end -}}
{{- end -}}
{{- $level := ternary "" (toString .process.logLevel) (kindIs "invalid" .process.logLevel) -}}
{{- if and (ne $level "") (not (or (regexMatch "(?i)^(debug|info|error|panic)$" $level) (and (regexMatch "^[0-9]+$" $level) (regexMatch "[1-9]" $level) (le (len $level) 3) (le (atoi $level) 127)))) -}}
{{- $errors = append $errors (printf "- %s.logLevel %q is not one of debug, info, error, panic or a positive integer up to 127." .path $level) -}}
{{- end -}}
{{- join "\n" $errors -}}
{{- end -}}

{{- define "gremlin-operator.validateValues.switches" -}}
{{- $errors := list -}}
{{- range $path, $value := dict "installNamespace.create" .Values.installNamespace.create "reconciler.serviceAccount.create" .Values.reconciler.serviceAccount.create "credentialManager.serviceAccount.create" .Values.credentialManager.serviceAccount.create -}}
{{- if not (kindIs "bool" $value) -}}
{{- $errors = append $errors (printf "- %s must be true or false, but is %s." $path (toJson $value)) -}}
{{- end -}}
{{- end -}}
{{- if not (kindIs "bool" .Values.agent.nodeRead.enabled) -}}
{{- $errors = append $errors (printf "- agent.nodeRead.enabled must be true or false, but is %s." (toJson .Values.agent.nodeRead.enabled)) -}}
{{- end -}}
{{- if not (kindIs "bool" .Values.openshift.enabled) -}}
{{- $errors = append $errors (printf "- openshift.enabled must be true or false, but is %s." (toJson .Values.openshift.enabled)) -}}
{{- end -}}
{{- join "\n" $errors -}}
{{- end -}}
