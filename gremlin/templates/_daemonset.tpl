{{/*
gremlin.daemonset renders one Gremlin DaemonSet from an already-resolved context. Deciding how many
DaemonSets exist and what goes in each is the caller's job (see daemonset.yaml); this template only
renders what it is handed.

Context: dict
  "root"           $        # the chart root context
  "name"           <string> # DaemonSet name
  "selectorLabels" <dict>   # extra selector/pod labels, so DaemonSets sharing a cluster do not
                            #   fight over each other's pods (optional; default none)
  "gpu"            <dict>   # a gremlin.gpu.<vendor> config block (optional; default no GPU config)
  "affinity"       <yaml>   # rendered affinity (optional; defaults to .Values.affinity)
*/}}
{{- define "gremlin.daemonset" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $selectorLabels := default (dict) .selectorLabels -}}
{{- $gpu := default (dict) .gpu -}}
{{- $affinity := .affinity -}}
{{- if and (not $affinity) $root.Values.affinity -}}{{- $affinity = toYaml $root.Values.affinity -}}{{- end -}}
{{- /* CDI device: global gremlin.gpu.cdiDevice, optionally overridden per vendor block */ -}}
{{- $cdiDevice := "" -}}
{{- with $gpu -}}{{- $cdiDevice = default $root.Values.gremlin.gpu.cdiDevice .cdiDevice -}}{{- end -}}
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ $name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ include "gremlin.name" $root }}
    helm.sh/chart: {{ include "gremlin.chart" $root }}
    app.kubernetes.io/instance: {{ $root.Release.Name }}
    app.kubernetes.io/managed-by: {{ $root.Release.Service }}
    version: v1
    {{- with $selectorLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- if $root.Values.gremlin.podLabels }}
    {{- toYaml $root.Values.gremlin.podLabels | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "gremlin.name" $root }}
      {{- with $selectorLabels }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
  {{- if $root.Values.gremlin.updateStrategy }}
  updateStrategy:
    {{- toYaml $root.Values.gremlin.updateStrategy | nindent 4 }}
  {{- end }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "gremlin.name" $root }}
        helm.sh/chart: {{ include "gremlin.chart" $root }}
        app.kubernetes.io/instance: {{ $root.Release.Name }}
        app.kubernetes.io/managed-by: {{ $root.Release.Service }}
        version: v1
        {{- with $selectorLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if $root.Values.gremlin.podLabels }}
        {{- toYaml $root.Values.gremlin.podLabels | nindent 8 }}
        {{- end }}
      {{- if or $root.Values.gremlin.apparmor $root.Values.gremlin.installApparmorProfile $root.Values.gremlin.podSecurity.seccomp.enabled $root.Values.gremlin.podSecurity.securityContextConstraints.create $root.Values.gremlin.podAnnotations $cdiDevice }}
      annotations:
        {{- if $root.Values.gremlin.apparmor }}
        container.apparmor.security.beta.kubernetes.io/{{ $root.Chart.Name }}: {{ $root.Values.gremlin.apparmor }}
        {{- else if $root.Values.gremlin.installApparmorProfile }}
        container.apparmor.security.beta.kubernetes.io/{{ $root.Chart.Name }}: {{ "localhost/gremlin-agent" }}
        {{- end }}
        {{- if $root.Values.gremlin.podSecurity.seccomp.enabled }}
        container.seccomp.security.alpha.kubernetes.io/{{ $root.Chart.Name }}: {{ $root.Values.gremlin.podSecurity.seccomp.profile }}
        {{- end }}
        {{- if $root.Values.gremlin.podSecurity.securityContextConstraints.create }}
        openshift.io/required-scc: "gremlin"
        {{- end }}
        {{- if $cdiDevice }}
        cdi.k8s.io/gremlin-gpu: {{ $cdiDevice | quote }}
        {{- end }}
        {{- if $root.Values.gremlin.podAnnotations }}
        {{- toYaml $root.Values.gremlin.podAnnotations | nindent 8 }}
        {{- end }}
      {{- end }}
    spec:
      serviceAccountName: gremlin
      {{- with $gpu.runtimeClassName }}
      runtimeClassName: {{ . }}
      {{- end }}
      {{- with $affinity }}
      affinity: {{ . | trimSuffix "\n" | nindent 8 }}
      {{- end }}
      {{- if $root.Values.nodeSelector }}
      nodeSelector: {{ toYaml $root.Values.nodeSelector | trimSuffix "\n" | nindent 8 }}
      {{- end }}
      {{- if $root.Values.tolerations }}
      tolerations: {{ toYaml $root.Values.tolerations | trimSuffix "\n" | nindent 8 }}
      {{- end }}
      dnsPolicy: {{ $root.Values.gremlin.dnsPolicy }}
      hostPID: {{ $root.Values.gremlin.hostPID }}
      hostNetwork: {{ $root.Values.gremlin.hostNetwork }}
      {{- if $root.Values.image.pullSecret }}
      imagePullSecrets:
        - name: {{ $root.Values.image.pullSecret }}
      {{- end }}
      {{- if and $root.Values.gremlin.podSecurity.seccomp.enabled (eq "localhost/gremlin" $root.Values.gremlin.podSecurity.seccomp.profile) }}
      initContainers:
        - name: seccomp-init
          image: {{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}
          imagePullPolicy: {{ $root.Values.image.pullPolicy }}
          volumeMounts:
            - mountPath: {{ $root.Values.gremlin.podSecurity.seccomp.root }}
              name: seccomp-root
            - mountPath: /gremlin
              name: seccomp-profile
          command:
            - cp
            - /gremlin/seccomp.json
            - {{ $root.Values.gremlin.podSecurity.seccomp.root }}/gremlin
      {{- end }}
      containers:
      - name: {{ $root.Chart.Name }}
        image: {{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}
        args: [ "daemon" ]
        imagePullPolicy: {{ $root.Values.image.pullPolicy }}
        {{- if $root.Values.gremlin.resources }}
        resources: {{ toYaml $root.Values.gremlin.resources | nindent 10 }}
        {{- end }}
        securityContext:
          privileged: {{ $root.Values.gremlin.podSecurity.privileged }}
          allowPrivilegeEscalation: {{ $root.Values.gremlin.podSecurity.allowPrivilegeEscalation }}
          capabilities:
            add: {{ toYaml $root.Values.gremlin.podSecurity.capabilities | nindent 14 }}
          {{- if $root.Values.gremlin.podSecurity.seLinuxOptions }}
          seLinuxOptions: {{ toYaml $root.Values.gremlin.podSecurity.seLinuxOptions | nindent 12 }}
          {{- end }}
          readOnlyRootFilesystem: {{ $root.Values.gremlin.podSecurity.readOnlyRootFilesystem }}
        env:
          - name: GREMLIN_TEAM_ID
            {{- /* If we aren't managing this secret and a teamID was supplied, assume teamID is not in the external secret */}}
            {{- if (and (not $root.Values.gremlin.secret.managed) (default $root.Values.gremlin.teamID $root.Values.gremlin.secret.teamID)) }}
            value: {{ default $root.Values.gremlin.teamID $root.Values.gremlin.secret.teamID | quote }}
            {{- else }}
            valueFrom:
              secretKeyRef:
                name:  {{ include "gremlin.secretName" $root }}
                key: GREMLIN_TEAM_ID
            {{- end }}

          {{- if (eq (include "gremlin.secretType" $root) "secret") }}
          - name: GREMLIN_TEAM_SECRET
            valueFrom:
              secretKeyRef:
                name: {{ include "gremlin.secretName" $root }}
                key: GREMLIN_TEAM_SECRET
          {{- else }}
          - name: GREMLIN_TEAM_CERTIFICATE_OR_FILE
            {{- /* If managed outside of this chart, or if the value is a literal, reference the secret as a file */}}
            {{- if or (not $root.Values.gremlin.secret.managed)  (hasPrefix "-----BEGIN" $root.Values.gremlin.secret.certificate) }}
            value: file:///var/lib/gremlin/cert/gremlin.cert
            {{- else }}
            value: {{ $root.Values.gremlin.secret.certificate }}
            {{- end }}
          - name: GREMLIN_TEAM_PRIVATE_KEY_OR_FILE
            {{- /* If managed outside of this chart, or if the value is a literal, reference the secret as a file */}}
            {{- if or (not $root.Values.gremlin.secret.managed) (hasPrefix "-----BEGIN" $root.Values.gremlin.secret.certificate) }}
            value: file:///var/lib/gremlin/cert/gremlin.key
            {{- else }}
            value: {{ $root.Values.gremlin.secret.key }}
            {{- end }}
          {{- end }}
          - name: GREMLIN_IDENTIFIER
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: GREMLIN_CLIENT_TAGS
            value: {{ $root.Values.gremlin.client.tags }}
          - name: GREMLIN_COLLECT_DNS
            value: {{ $root.Values.gremlin.collect.dns | quote }}
          - name: GREMLIN_SERVICE_URL
            value: {{ include "gremlinServiceUrl" $root }}
          {{- if not $root.Values.gremlin.features.pushCIDRTags.enabled }}
          - name: GREMLIN_PUSH_POD_CIDR_TAGS
            value: "false"
          - name: GREMLIN_PUSH_ZONE_CIDR_TAGS
            value: "false"
          {{- end }}
          {{- if $root.Values.gremlin.proxy.url }}
          - name: https_proxy
            value: {{ $root.Values.gremlin.proxy.url }}
          {{- end }}
          {{- if $root.Values.ssl.certFile }}
          - name: SSL_CERT_FILE
            value: /etc/gremlin/ssl/certfile.pem
          {{- end }}
          {{- if $root.Values.ssl.certDir }}
          - name: SSL_CERT_DIR
            value: {{ $root.Values.ssl.certDir }}
          {{- end }}
          {{- if include "gremlinTlsIdentityEnv" $root }}
          {{- include "gremlinTlsIdentityEnv" $root | nindent 10 }}
          {{- end }}
          {{- with $gpu.env }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
          {{- with $root.Values.gremlin.extraEnv }}
            {{- toYaml . | nindent 10 }}
          {{- end }}
        volumeMounts:
          - name: gremlin-state
            mountPath: /var/lib/gremlin
            readOnly: false
          - name: gremlin-executions
            mountPath: /var/lib/gremlin/executions
            readOnly: false
          - name: gremlin-logs
            mountPath: /var/log/gremlin
            readOnly: false
          - name: cgroup-root
            mountPath: /sys/fs/cgroup
            readOnly: false
          {{- if include "containerMounts" $root }}
          {{- include "containerMounts" $root | nindent 10 }}
          {{- end }}
          {{- if (eq (include "gremlin.secretType" $root) "certificate") }}
          - name: gremlin-cert
            mountPath: /var/lib/gremlin/cert
            readOnly: true
          {{- end }}
          {{- if $root.Values.ssl.certFile }}
          - name: ssl-cert-file
            mountPath: /etc/gremlin/ssl
            readOnly: true
          {{- end }}
          {{- if include "gremlinTlsIdentityVolumeMounts" $root }}
          {{- include "gremlinTlsIdentityVolumeMounts" $root | nindent 10 }}
          {{- end }}
          {{- with $gpu.volumeMounts }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
          {{- if include "gremlinGpuOpenclIcdActiveFromSpec" (dict "root" $root "gpu" $gpu) }}
          - name: gremlin-opencl-icd
            mountPath: /etc/OpenCL/vendors/{{ $gpu.openclIcd.filename }}
            subPath: {{ $gpu.openclIcd.filename }}
            readOnly: true
          {{- end }}
      volumes:
        - name: cgroup-root
          hostPath:
            path: {{ $root.Values.gremlin.cgroup.root }}
        {{- if include "containerVolumes" $root }}
        {{- include "containerVolumes" $root | nindent 8 }}
        {{- end }}
        # The Gremlin daemon communicates with Gremlin sidecars via its state directory.
        - name: gremlin-state
          emptyDir:
            medium: Memory
        - name: gremlin-executions
          hostPath:
            path: /var/lib/gremlin/executions
        # The Gremlin daemon forwards logs from the Gremlin sidecars to the Gremlin control plane
        # These logs should be shared with the host
        - name: gremlin-logs
          hostPath:
            path: /var/log/gremlin
        {{- if (eq (include "gremlin.secretType" $root) "certificate") }}
        - name: gremlin-cert
          secret:
            secretName: {{ include "gremlin.secretName" $root }}
        {{- end }}
        {{- if and $root.Values.gremlin.podSecurity.seccomp.enabled (eq "localhost/gremlin" $root.Values.gremlin.podSecurity.seccomp.profile) }}
        - name: seccomp-root
          hostPath:
            path: {{ $root.Values.gremlin.podSecurity.seccomp.root }}
        - name: seccomp-profile
          configMap:
            name: {{ template "gremlin.fullname" $root }}-seccomp
        {{- end }}
        {{- if $root.Values.ssl.certFile }}
        - name: ssl-cert-file
          secret:
            secretName: ssl-cert-file
        {{- end }}
        {{- if include "gremlinTlsIdentityVolumes" $root }}
        {{- include "gremlinTlsIdentityVolumes" $root | nindent 8 }}
        {{- end }}
        {{- with $gpu.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if include "gremlinGpuOpenclIcdActiveFromSpec" (dict "root" $root "gpu" $gpu) }}
        - name: gremlin-opencl-icd
          configMap:
            name: {{ include "gremlin.fullname" $root }}-opencl-icd
        {{- end }}
{{- if $root.Values.gremlin.priorityClassName }}
      priorityClassName: {{ $root.Values.gremlin.priorityClassName }}
{{- end }}
{{- end -}}
