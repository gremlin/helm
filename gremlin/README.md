# Gremlin Client Helm Chart

## Prerequisites

* Kubernetes with apps/v1 available
* Helm 3. The uninstall instructions below use Helm 3 syntax.
* Adding the Gremlin helm repo. `helm repo add gremlin https://helm.gremlin.com/ && helm repo update`
* Permission to create cluster-scoped resources. With default values this chart creates
  `ClusterRole/gremlin-metadata-reader`, `ClusterRoleBinding/gremlin-metadata-reader`,
  `ClusterRole/gremlin-watcher` and `ClusterRoleBinding/chao`. If you cannot create
  cluster-scoped resources, set `gremlin.serviceAccount.create=false` and
  `chao.serviceAccount.create=false` and pre-create ServiceAccounts named exactly `gremlin`
  and `chao` in the release namespace — both names are fixed in the pod specs. Note that
  disabling them removes permissions the agent and Chao use; check with Gremlin support
  before doing so in production.

## Configuration

By default this chart will install the gremlin client on all nodes in the
cluster.

The following table lists common configurable parameters of the chart and
their default values. See values.yaml for all available options.

|       Parameter                        |           Description                                          | Default                                                                                                |
|----------------------------------------|----------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| `image.pullPolicy`                     | Container pull policy                                          | `Always`                                                                                               |
| `image.pullSecret`                     | Pull secret for a private registry                             | `""` (When empty, no authentication is used)                                                           |
| `image.repository`                     | Container image to use                                         | `gremlin/gremlin`                                                                                      |
| `image.tag`                            | Container image tag to deploy. [See below](#pinning-the-agent-version) | `latest`                                                                                               |
| `chaoimage.pullPolicy`                 | Container pull policy for the `chao` container                 | `Always`                                                                                               |
| `chaoimage.pullSecret`                 | Pull secret for a private registry for the `chao` container    | `""` (When empty, no authentication is used)                                                           |
| `chaoimage.repository`                 | Container image to use for the `chao` container                | `gremlin/chao`                                                                                         |
| `chaoimage.tag`                        | Container image tag to deploy for the `chao` container. [See below](#pinning-the-agent-version) | `latest`                                                                                               |
| `nodeSelector`                         | Map of node labels for pod assignment for the `gremlin` container | `{}`                                                                                                   |
| `tolerations`                          | List of node taints to tolerate for the `gremlin` container    | `[]`                                                                                                   |
| `affinity`                             | Map of node/pod affinities for the `gremlin` container         | `{}`                                                                                                   |
| `livenessProbe`                        | A Kubernetes `Probe` for the `gremlin` container                | `{}`                                                                                        |
| `readinessProbe`                       | A Kubernetes `Probe` for the `gremlin` container                | `{}`                                                                                        |
| `startupProbe`                         | A Kubernetes `Probe` for the `gremlin` container                | `{}`                                                                                        |
| `initContainers`                       | Additional init containers for the `gremlin` DaemonSet, appended after `seccomp-init` when enabled. A name colliding with one the chart manages fails the install | `[]`                                          |
| `extraVolumes`                         | Additional volumes for the `gremlin` DaemonSet. A name colliding with one the chart manages fails the install | `[]`                                                                       |
| `extraVolumeMounts`                    | Additional volume mounts for the `gremlin` container. A name colliding with one the chart manages fails the install | `[]`                                                                |
| `lifecycle`                            | A Kubernetes `Lifecycle` object (`preStop`/`postStart`) for the `gremlin` container | `{}`                                                                                   |
| `envFrom`                              | Additional `ConfigMap`/`Secret` sources for the `gremlin` container's environment. Unlike `gremlin.extraEnv`, does not override chart-managed env vars (Kubernetes gives `env:` precedence over `envFrom:`) | `[]`                    |
| `terminationGracePeriodSeconds`        | Termination grace period, in seconds, for the `gremlin` DaemonSet's pods | (Kubernetes default: `30`)                                                                |
| `dnsConfig`                            | A Kubernetes `PodDNSConfig` for the `gremlin` DaemonSet's pod spec | `{}`                                                                                    |
| `hostAliases`                          | A list of Kubernetes `HostAlias` entries for the `gremlin` DaemonSet's pod spec. No effect while `gremlin.hostNetwork` is `true` (the default) | `[]`                                          |
| `podSecurityContext`                   | A Kubernetes pod-level `SecurityContext` for the `gremlin` DaemonSet, alongside the existing container-level `gremlin.podSecurity.*` settings | `{}`                                        |
| `chao.podLabels`                       | Kubernetes labels applied to the chao deployment and it's Pods | `{}`                                                                                                   |
| `chao.priorityClassName`               | The name of the priority class to use for the Chao deployment  | `""`                                                                                                   |
| `chao.nodeSelector`                    | Map of node labels for pod assignment for the `chao` container | `{}`                                                                                                   |
| `chao.tolerations`                     | List of node taints to tolerate for the `chao` container       | `[]`                                                                                                   |
| `chao.affinity`                        | Map of node/pod affinities for the `chao` container            | `{}`                                                                                                   |
| `chao.create`                          | Enable kubernetes targeting by installing k8s client           | true                                                                                                   |
| `chao.resources`                       | Set resource requests and limits for the chao deployment       | `{}`                                                                                                   |
| `chao.extraEnv`                        | Specify any arbitrary environment variables to pass to the Chao deployment. | `[]`                                                                                                   |
| `chao.livenessProbe`                   | A Kubernetes `Probe` for the `chao` container                   | `{}`                                                                                        |
| `chao.readinessProbe`                  | A Kubernetes `Probe` for the `chao` container                   | `{}`                                                                                        |
| `chao.startupProbe`                    | A Kubernetes `Probe` for the `chao` container                   | `{}`                                                                                        |
| `chao.initContainers`                  | Additional init containers for the `chao` deployment. A name colliding with one the chart manages fails the install | `[]`                                                                       |
| `chao.extraVolumes`                    | Additional volumes for the `chao` deployment. A name colliding with one the chart manages fails the install | `[]`                                                                               |
| `chao.extraVolumeMounts`               | Additional volume mounts for the `chao` container. A name colliding with one the chart manages fails the install | `[]`                                                                          |
| `chao.lifecycle`                       | A Kubernetes `Lifecycle` object (`preStop`/`postStart`) for the `chao` container | `{}`                                                                                   |
| `chao.envFrom`                         | Additional `ConfigMap`/`Secret` sources for the `chao` container's environment. Unlike `chao.extraEnv`, does not override chart-managed env vars (Kubernetes gives `env:` precedence over `envFrom:`) | `[]`                        |
| `chao.terminationGracePeriodSeconds`   | Termination grace period, in seconds, for the `chao` deployment's pods | (Kubernetes default: `30`)                                                                 |
| `chao.dnsConfig`                       | A Kubernetes `PodDNSConfig` for the `chao` deployment's pod spec | `{}`                                                                                       |
| `chao.hostAliases`                     | A list of Kubernetes `HostAlias` entries for the `chao` deployment's pod spec | `[]`                                                                                  |
| `chao.podSecurityContext`              | A Kubernetes pod-level `SecurityContext` for the `chao` deployment's pod spec | `{}`                                                                                  |
| `chao.namespaces`                      | List of namespaces for Gremlin to watch for attacking          | `[]`                                                                                                   |
| `chao.excludedNamespaces`              | List of namespaces Gremlin should never report or attack (mutually exclusive with `chao.namespaces`) | `[]`                                                                                                   |
| `chao.features.dynamicQuery.enabled`   | Let Gremlin query Kubernetes resources beyond the fixed set Chao watches by default. [See below](#chao-dynamic-queries) | `false`                                                                                                |
| `chao.features.dynamicQuery.allowlist` | RBAC rules describing the resources Chao may query. [See below](#chao-dynamic-queries) | The resources describing a cluster's shape, scheduling, and health (see values.yaml)                   |
| `chao.tls.identity.enabled`            | Configure a TLS client identity for the Chao Deployment. [See below](#client-mtls-identity) | `false`                                                                                                |
| `gremlin.podLabels`           | Kubernetes labels applied to the Gremlin Agent's DaemonSet and it's pods| `{}`                                                                                                   |
| `gremlin.apparmor`                     | Apparmor profile to set for the Gremlin Daemon                 | `""` (When empty, no profile is set)                                                                   |
| `gremlin.installApparmorProfile`       | Have Gremlin install their own [Apparmor Profile](agent_apparmor.profile) (NOTE: `gremlin.apparmor` overrides this) | `false`                                                                                                |
| `gremlin.container.driver`             | Specifies which container driver with which to run Gremlin. [See example][driverexample] | `any`                                                                                                  |
| `gremlin.cgroup.root`                  | Specifies the absolute path for the cgroup controller root on target host systems | `/sys/fs/cgroup`                                                                                       |
| `gremlin.serviceAccount.create`        | Specifies whether Gremlin's kubernetes service account should be created by this helm chart | `true`                                                                                                 |
| `gremlin.podSecurity.allowPrivilegeEscalation` | Allows Gremlin containers privilege escalation powers  | `false`                                                                                                |
| `gremlin.podSecurity.capabilities`     | Specifies which Linux capabilities should be granted to Gremlin| `[KILL, NET_ADMIN, SYS_BOOT, SYS_TIME, DAC_READ_SEARCH, SYS_RESOURCE, SYS_ADMIN, SYS_PTRACE, NET_RAW]` |
| `gremlin.podSecurity.seLinuxOptions`   | Specifies SELinux options to apply to the Gremlin Daemonset container securityContext. WARNING: This option should be enabled with caution as it is likely to break the GremlinAgent or your Kubernetes installation. Gremlin recommends users instead install a custom SELinux policy that provides integration with the labels already defined on the target system so that paths do not need to be relabeled. See https://github.com/gremlin/selinux-policies | `{}`                                                                                                   |
| `gremlin.podSecurity.readOnlyRootFilesystem` | Forces the Gremlin Daemonset containers to run with a read-only root filesystem | `false`                                                                                                |
| `gremlin.podSecurity.supplementalGroups.rule` | Specifies the Linux groups the Gremlin Daemonset containers should run as | `RunAsAny`                                                                                             |
| `gremlin.podSecurity.fsGroup.rule`     | Specifies the Linux groups applied to mounted volumes          | `RunAsAny`                                                                                             |
| `gremlin.podSecurity.volumes`          | Specifies the volume types the Gremlin Daemonset is allowed to use | `[configMap, secret, hostPath, emptyDir]`                                                              |
| `gremlin.podSecurity.podSecurityPolicy.create` | When true, Gremlin creates and uses a custom PodSecurityPolicy, granting all behaviors Gremlin needs | `false`                                                                                                |
| `gremlin.podSecurity.podSecurityPolicy.seLinux` | Sets the SecurityContext for the PSP used by the Gremlin Daemonset | `{ rule: MustRunAs, seLinuxOptions: { type: gremlin.process, level: s0-s0:c0.c1023 } }`                |
| `gremlin.podSecurity.podSecurityPolicy.runAsUser.rule`   | Specifies the Linux user the Gremlin Daemonset containers should run as | `RunAsAny`                                                                                             |
| `gremlin.podSecurity.securityContextConstraints.create` | When true, Gremlin creates and uses a custom SecurityContextConstraints, granting all behaviors Gremlin needs | `false`                                                                                                |
| `gremlin.podSecurity.securityContextConstraints.allowHostDirVolumePlugin` | Specifies whether the Gremlin Daemonset has access to host path directories as mounted volumes | `true`                                                                                                 |
| `gremlin.podSecurity.securityContextConstraints.seLinuxContext` | Sets the SecurityContext for the SCC used by the Gremlin Daemonset | `{ type: MustRunAs, seLinuxOptions: { type: spc_t, level: s0-s0:c0.c1023 } }`                          |
| `gremlin.podSecurity.securityContextConstraints.runAsUser.type`   | Specifies the Linux user the Gremlin Daemonset containers should run as | `RunAsAny`                                                                                             |
| `gremlin.podSecurity.privileged`       | Determines whether the Gremlin Daemonset should run privileged containers | `false`                                                                                                |
| `gremlin.podSecurity.seccomp.enabled`  | Determines whether the Gremlin Daemonset should be annotated with the seccomp profile | `false`                                                                                                |
| `gremlin.podSecurity.seccomp.profile`  | Describes the name of the seccomp profile to use               | `localhost/gremlin`                                                                                    |
| `gremlin.secret.managed`               | Specifies whether Gremlin should manage its secrets with Helm  | `false`                                                                                                |
| `gremlin.secret.type`                  | The type of certificate to use, can be either `certificate` or `secret` | `certificate`                                                                                          |
| `gremlin.serviceUrl`                   | Base URL of the Gremlin API the agent and Chao report to. The values file generated at https://app.gremlin.com/getting-started always sets this explicitly, so you rarely need to change it; override it for Gremlin Private Edition | `https://api.gremlin.com/v1`                                                                           |
| `gremlin.secret.name`                  | Name of the Secret holding the credentials, for example when pointing at an externally managed secret | `gremlin-team-cert` when `gremlin.secret.managed=false`, `gremlin-secret` when `true`                  |
| `gremlin.secret.teamID`                | Gremlin Team ID to authenticate with                           | `""`                                                                                                   |
| `gremlin.secret.clusterID`             | Arbitrary string that uniquely identifies your cluster (e.g. `my-production-cluster`) | `""`                                                                                                   |
| `gremlin.secret.certificate`           | Contents of the certificate. Required if using managed secrets of `type=certificate` | `""`                                                                                                   |
| `gremlin.secret.key`                   | Contents of the private key. Required if using managed secrets of `type=certificate` | `""`                                                                                                   |
| `gremlin.secret.teamSecret`            | Gremlin's team secret. Required if using managed secrets of `type=secret`  | `""`                                                                                                   |
| `gremlin.resources`                    | Set resource requests and limits                               | `{}`                                                                                                   |
| `gremlin.dnsPolicy`                    | The DNS policy to use for the Gremlin DaemonSet                | `ClusterFirstWithHostNet`                                                                              |
| `gremlin.hostPID`                      | Enable host-level process killing                              | `true`                                                                                                 |
| `gremlin.hostNetwork`                  | Enable host-level network attacks                              | `true`                                                                                                 |
| `gremlin.priorityClassName`            | The priority class to use for the agent DaemonSet              | `""`                                                                                                   |
| `gremlin.client.tags`                  | Comma-separated list of `key=value` tag pairs to assign to this client. Commas must be backslash-escaped when using `--set`; see [Example Usage](#example-usage) | `""`                                                                                                   |
| `gremlin.proxy.url`                    | Specifies the http proxy the agent should use to communicate with api.gremlin.com. | `""` (ignored)                                                                                         |                                       |
| `gremlin.extraEnv`                     | Specify any arbitrary environment variables to pass to the Gremlin Agent daemonset. | `[]`                                                                                                   |
| `gremlin.features.discoverDestinationService.enabled` | Enable discovery of a destination service in a service mesh to resolve hostnames | `false`                                                                                                |
| `gremlin.features.pushCIDRTags.enabled` | Push tags describing the CIDR ranges associated with the host the agent runs on | `true`                                                                                                 |
| `gremlin.collect.dns`                  | Specifies whether Gremlin should collect DNS call information | `true`                                                                                                 |
| `gremlin.tls.identity.enabled`         | Configure a TLS client identity for the agent DaemonSet. [See below](#client-mtls-identity) | `false`                                                                                                |
| `gremlin.gpu.enabled`                  | Expose host GPU/OpenCL drivers to the agent for the GPU attack | `false`                                                                                                |
| `gremlin.gpu.cdiDevice`                | CDI device to inject via pod annotation (for CDI-based runtimes) | `""`                                                                                                   |
| `gremlin.gpu.projectOpenclIcd`         | Project a vendor's OpenCL ICD registry file into the container  | `true`                                                                                                 |
| `gremlin.gpu.vendors`                  | Vendor blocks to target; one DaemonSet is created per entry     | `[nvidia, amd]`                                                                                        |
| `gremlin.gpu.<vendor>`                 | Per-vendor config block: `nodeSelector`, `runtimeClassName`, `env`, `volumes`, `volumeMounts`, `openclIcd` | see `values.yaml`                                                                                      |
| `ssl.certFile`                         | Add a certificate file to Gremlin's set of certificate authorities. This argument expects a file containing the certificate(s) you wish to add. When set, this chart creates secret (`ssl-cert-file`) with the contents and passes it to both agents. This value is ignored when blank or absent. | `""` (ignored)                                                                                         |
| `ssl.certDir`                          | sets the SSL_CERT_DIR environment variable on the both agents. Unlike ssl.certFile, this value accepts only a path to an existing directory on the Kubernetes nodes. This value is ignored when blank or absent. | `""` (ignored)                                                                                         |

Specify each parameter using the `--set[-file] key=value[,key=value]` argument to `helm install`.

### Example Usage
```
$ helm install gremlin gremlin/gremlin \
  --namespace gremlin --create-namespace \
  --set       'gremlin.client.tags=env=prod\,team=core' \
  --set       gremlin.secret.clusterID=my-cluster \
  --set       gremlin.hostNetwork=true \
  --set       gremlin.hostPID=true \
  --set       gremlin.secret.managed=true \
  --set       gremlin.secret.type=certificate \
  --set       gremlin.secret.teamID="$GREMLIN_TEAM_ID" \
  --set-file  gremlin.secret.certificate=/path/to/gremlin.cert \
  --set-file  gremlin.secret.key=/path/to/gremlin.key \
  --set       'tolerations[0].effect=NoSchedule' \
  --set       'tolerations[0].key=node-role.kubernetes.io/master' \
  --set       'tolerations[0].operator=Exists'
```
_note_: Depending on your shell you may need different quoting around `tolerations[0]`

### Pinning the agent version

`image.tag` and `chaoimage.tag` both default to `latest` with `pullPolicy: Always`, so every pod restart can pick up a newer build. Pin both to bring that upgrade under your own control:

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set image.tag=<agent version> \
    --set image.pullPolicy=IfNotPresent \
    --set chaoimage.tag=<chao version> \
    --set chaoimage.pullPolicy=IfNotPresent
```

Available tags are published on Docker Hub under `gremlin/gremlin` and `gremlin/chao`. The two images are versioned independently: pinning `image.tag` leaves Chao floating on `latest`, and pinning `chaoimage.tag` leaves the agent floating. Leaving `pullPolicy: Always` against a pinned tag only adds a registry round trip to every pod start.

The chart records `annotations.minimumAppVersion`: the oldest agent version these templates are known to work with. It is informational only. Nothing in the chart enforces it, so pinning `image.tag` below that floor installs without complaint and is not a supported configuration.

## Chao dynamic queries

By default, Chao reads a fixed set of Kubernetes resources — the ones named in the `gremlin-watcher` ClusterRole. Enabling `chao.features.dynamicQuery` lets Gremlin query resources beyond that set. `allowlist` says which ones: each entry maps directly onto an RBAC rule and accepts `apiGroups`, `resources`, and an optional `verbs`, and is added to the `gremlin-watcher` ClusterRole. Every entry has to name its `apiGroups` and `resources` — nothing is wildcarded on your behalf, and an entry that leaves `apiGroups` out fails the install rather than being granted across every API group.

**RBAC is the boundary, and Chao holds a denylist inside it.** Chao is told the feature is on (the `-dynamic_query` flag) but is never handed the allowlist — it discovers what it may read by being refused, and handles the `403` itself. Anything absent from the allowlist is refused by the API server, so the outer limit is not something Chao has to be trusted to honor. Kubernetes RBAC has no deny rule, so a grant is the only place that outer limit can be expressed; `denylist` is the inner one, enforced by Chao, for carving resources back out of a grant that is broader than you want. It is passed as `-deny_resources` and adds to a built-in denylist that always applies and cannot be turned off.

Dynamic queries are **read-only**. `verbs` defaults to `get` and `list` and may narrow to a subset of those two; any other verb — including `watch` and the `"*"` wildcard — fails the install. Chao cannot watch these resources, so it polls them. The base `gremlin-watcher` rules are unaffected and keep their `watch`.

### What the default grants

The default covers the resources that describe a cluster's shape, scheduling, and health — `endpoints`, `events`, `persistentvolumeclaims`, `jobs`, `networkpolicies`, `storageclasses`, `customresourcedefinitions`, and the like — on top of the workloads the base `gremlin-watcher` rules already watch. See [values.yaml](values.yaml) for the full list.

Some things are deliberately left out of it:

| Left out of the default | Why |
| --- | --- |
| `secrets`, `configmaps` | Both commonly hold connection strings, tokens, and API keys |
| `pods/log` | Application logs commonly contain tokens and personal data |
| `nodes/proxy` | Reaches the kubelet API, exposing every pod spec — and its environment — on a node |
| `services/proxy` | An HTTP tunnel into any in-cluster service, bypassing NetworkPolicy |
| RBAC roles and bindings | A map of which identity is allowed to do what, which is reconnaissance for privilege escalation |

Note that an RBAC `resources: ["*"]` wildcard matches subresources as well as resources, so a wildcard entry reaches `pods/log` and the proxy subresources too.

### Changing what Chao can reach

Setting `allowlist` replaces the default outright, so name every resource Gremlin should reach:

```yaml
chao:
  features:
    dynamicQuery:
      enabled: true
      allowlist:
        - apiGroups: [""]
          resources: ["pods", "services"]
        - apiGroups: ["apps"]
          resources: ["deployments"]
          verbs: ["get"]
        - apiGroups: ["argoproj.io"]
          resources: ["applications"]
```

which grants Chao read access to `pods`, `services`, and Argo CD `applications`, plus `get` on `deployments`. Enabling the feature with an allowlist that names no resources fails the install rather than silently deploying a Chao that cannot query anything.

### Denying resources inside the allowlist

`denylist` names resources Chao may never read, as `resource.group` or `*.group`:

```yaml
chao:
  features:
    dynamicQuery:
      enabled: true
      allowlist:
        - apiGroups: ["example.com"]
          resources: ["*"]
      denylist:
        - "credentials.example.com"
        - "*.vault.example.com"
```

which grants Chao every resource in `example.com` except `credentials`, and denies the `vault.example.com` group outright. Entries are joined into one `-deny_resources` flag, so each has to be a single name with no commas or spaces. Use the empty group for core resources — `secrets.` rather than `secrets`.

Reach for this when an allowlist entry is broader than you want — a wildcard over a custom API group, say — and RBAC would need the grant enumerated resource by resource to express the same thing. It adds to Chao's built-in denylist, which always applies. Denying something the allowlist never granted is harmless but redundant: RBAC already refuses it.

## Client mTLS identity

When something between your cluster and the Gremlin API requires clients to present a certificate — a proxy or gateway terminating mutual TLS — `gremlin.tls.identity` and `chao.tls.identity` give the agent and Chao a client certificate and private key to present.

This is separate from `gremlin.secret`. That is how you authenticate *to* Gremlin; an mTLS identity is how you get *through* the network in between. A cluster that needs mTLS still needs its team credentials as well.

The agent and Chao are configured independently and take the same shape. Set `enabled: true` on the one you are configuring, then configure exactly one of three strategies:

| Strategy | Use when |
| --- | --- |
| `remoteSecret` | The certificate and key live in AWS Secrets Manager. You supply ARNs, which the chart passes through for the agent to resolve at runtime; no certificate material passes through Helm or is stored in a Kubernetes Secret. |
| `createSecret` | You hold the PEM content and want this chart to create the Kubernetes Secret. |
| `existingSecret` | The Secret already exists, from cert-manager or created out of band. |

A strategy takes effect only once all of its fields are set; a partially configured one is ignored. Configuring more than one strategy fully fails the install rather than silently choosing between them. Setting `enabled: false` disables the feature outright, whatever the strategies hold.

### Parameters

| Parameter | Description | Default |
|---|---|---|
| `gremlin.tls.identity.enabled` | Configure a TLS client identity for the agent DaemonSet | `false` |
| `gremlin.tls.identity.remoteSecret.cert` | AWS Secrets Manager ARN of the identity certificate | `""` |
| `gremlin.tls.identity.remoteSecret.key` | AWS Secrets Manager ARN of the identity private key | `""` |
| `gremlin.tls.identity.createSecret.name` | Name of the Secret this chart creates | `gremlin-tls-identity` |
| `gremlin.tls.identity.createSecret.cert` | PEM-encoded certificate, leaf plus any intermediates | `""` |
| `gremlin.tls.identity.createSecret.key` | PEM-encoded private key | `""` |
| `gremlin.tls.identity.existingSecret.name` | Name of an existing Secret to mount | `""` |
| `gremlin.tls.identity.existingSecret.cert` | Key within that Secret holding the certificate | `tls.crt` |
| `gremlin.tls.identity.existingSecret.key` | Key within that Secret holding the private key | `tls.key` |
| `chao.tls.identity.*` | The same nine settings for the Chao Deployment | as above, except `chao.tls.identity.createSecret.name`, which defaults to `chao-tls-identity` |

### remoteSecret

```yaml
gremlin:
  tls:
    identity:
      enabled: true
      remoteSecret:
        cert: "arn:aws:secretsmanager:us-east-1:123456789012:secret:gremlin-identity-cert"
        key: "arn:aws:secretsmanager:us-east-1:123456789012:secret:gremlin-identity-key"
```

The ARNs are passed through unchanged and the agent resolves them, so no Secret is created and nothing is mounted.

### createSecret

```yaml
gremlin:
  tls:
    identity:
      enabled: true
      createSecret:
        cert: |
          -----BEGIN CERTIFICATE-----
          ...
        key: |
          -----BEGIN PRIVATE KEY-----
          ...
```

The chart creates a Secret named by `createSecret.name` and mounts it read-only at `/var/lib/gremlin/tls/identity`. Supplying the key this way puts private key material in your values file, so treat that file accordingly.

### existingSecret

```yaml
gremlin:
  tls:
    identity:
      enabled: true
      existingSecret:
        name: gremlin-client-identity
```

The Secret is mounted read-only at `/var/lib/gremlin/tls/identity`. `existingSecret.cert` and `existingSecret.key` name the keys within it, and double as the mounted filenames — the defaults `tls.crt` and `tls.key` match what cert-manager produces, so a cert-manager Certificate needs only `name`.

### Confirming it is wired up

The agent reads its identity from the `GREMLIN_TLS_IDENTITY_CERTIFICATE` and `GREMLIN_TLS_IDENTITY_PRIVATE_KEY` environment variables; Chao takes the same two values as the `-tls_identity_cert` and `-tls_identity_key` command-line flags. Under `remoteSecret` both carry the ARN itself, and under the other two strategies both carry a path beneath `/var/lib/gremlin/tls/identity`.

## Installation

All Gremlin installations require authentication with our Gremlin control plane. There are two types of authentication available to Gremlin and Helm: `certificate`, and `secret`. You can find out more about these authentication types [here](https://www.gremlin.com/docs/infrastructure-layer/authentication/).

For this Helm chart, you'll need to download your team certificate or team secret from the Gremlin app.

**Certificate**
1. Go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team, and then `Details`
2. Click on the button labeled `Download` next to the current active certificate (If you don't see a button labelled `Download`, click on `Create New` to generate a new certificate)
3. When you unzip the downloaded file, you will see two files named `TEAM_NAME-client.priv_key.pem` and `TEAM_NAME-client.pub_cert.pem`. Rename these to `gremlin.key` and `gremlin.cert` respectively. These will be refered to as `/path/to/gremlin.cert` and `/path/to/gremlin.key` in later instructions.

**Secret**
1. Go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team, and then `Details`
2. Click on the button labeled `New` next to `Secret Key` (If you don't see a button labeled `New`, it's already been created. Talk to your administrator who should have the key or click the `Reset` button to create a new one)
3. You should see a value named `GREMLIN_TEAM_SECRET`, this will be refered to as `$GREMLIN_TEAM_SECRET` in later instructions

### With Managed Secrets

Some find it preferable to have this chart manage Gremlin's secret values instead of administrating them outside of Helm.

#### For certificate auth

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key
```

#### For secret auth

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set gremlin.secret.managed=true \
    --set gremlin.secret.type=secret \
    --set gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set gremlin.secret.teamSecret=$GREMLIN_TEAM_SECRET
```

### Without Managed Secrets

If you do not want this Chart to manage the kubernetes secrets for Gremlin, point this chart to your external secret with `gremlin.secret.name` and `gremlin.secret.type`

##### For secret auth
Create the external secret

```shell
kubectl create secret generic gremlin-team-secret \
    --namespace gremlin \
    --from-literal=GREMLIN_TEAM_ID=$GREMLIN_TEAM_ID \
    --from-literal=GREMLIN_TEAM_SECRET=$GREMLIN_TEAM_SECRET \
    --from-literal=GREMLIN_CLUSTER_ID=$GREMLIN_CLUSTER_ID
```

Install the Helm chart

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set gremlin.secret.name=gremlin-team-secret \
    --set gremlin.secret.type=secret # Default is gremlin.secret.type=certificate
```

#### For certificate auth

Create the external secret

```shell
kubectl create secret generic gremlin-team-cert \
    --namespace gremlin \
    --from-literal=GREMLIN_TEAM_ID=$GREMLIN_TEAM_ID \
    --from-literal=GREMLIN_CLUSTER_ID=$GREMLIN_CLUSTER_ID \
    --from-file=gremlin.cert=/path/to/gremlin.cert \
    --from-file=gremlin.key=/path/to/gremlin.key
```

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set gremlin.secret.name=gremlin-team-cert
```

### With an HTTP_PROXY

Gremlin can be configured to communicate with api.gremlin.com through an http_proxy. You can set this proxy with `gremlin.proxy.url`.

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key \
    --set      gremlin.proxy.url=http://proxy.net:3128
```

#### HTTPS_PROXY with custom certificate authority

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key \
    --set      gremlin.proxy.url=https://proxy.net:3128 \
    --set-file ssl.certFile=$HOME/Workspace/proxy/ca.pem
```

### With GPU Support

To let the GPU attack enumerate and target GPUs, enable `gremlin.gpu` and list the vendors your cluster has in `gremlin.gpu.vendors` (both `nvidia` and `amd` by default).

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key \
    --set      gremlin.gpu.enabled=true \
    --set      gremlin.gpu.vendors={nvidia}
```

_note_: The `nvidia` preset runs the agent under the `nvidia` RuntimeClass. If the Gremlin pod fails to start (for example, a `RuntimeClass not found` error), the RuntimeClass likely doesn't exist on your cluster. This chart does not create RuntimeClass objects. Ensure the RuntimeClass named by the vendor block exists (it is normally provided by the NVIDIA GPU Operator or your platform), or set the vendor's `runtimeClassName` to `""`.

#### One DaemonSet per vendor

Only some nodes have GPUs, and different nodes may have different GPU vendors, so a single GPU DaemonSet cannot run cluster-wide: nodes lacking the vendor's RuntimeClass or device mounts would fail to start the Gremlin pod. So whenever `gremlin.gpu.enabled` is set, the chart renders:

- one GPU DaemonSet per entry in `gremlin.gpu.vendors` (`<release>-gremlin-gpu-<vendor>`), scheduled via node affinity onto that vendor's nodes and carrying that vendor's GPU configuration, and
- one DaemonSet (`<release>-gremlin-gpu-none`) for every node that belongs to none of those vendors.

Each vendor's DaemonSet is rendered whether or not the cluster currently has nodes of that vendor; a vendor with no matching nodes simply schedules no pods. Trim `gremlin.gpu.vendors` to the vendors you care about to avoid the extra DaemonSets.

Scheduling uses each vendor block's `nodeSelector` (node labels such as `nvidia.com/gpu.present` / `amd.com/gpu.present`, set by the NVIDIA GPU Operator / Node Feature Discovery and the AMD GPU labeller): its DaemonSet requires those labels, and the `gpu-none` DaemonSet requires their absence. GPU nodes must therefore carry the vendor's `nodeSelector` labels for its DaemonSet to schedule. Any `affinity` you set is preserved — the vendor requirement is ANDed into it.

This chart does not create RuntimeClass objects; any RuntimeClass named by a vendor block must already exist on the cluster.

_note_: When GPU support is disabled the agent DaemonSet keeps its original `<release>-gremlin` name. Enabling GPU support replaces it with the per-vendor DaemonSets above (including `<release>-gremlin-gpu-none`), so Helm deletes the old DaemonSet and its pods are recreated by the new ones. The per-vendor DaemonSets also carry an extra `gremlin.com/gpu` pod-selector label so each only manages its own pods.

### Verifying the installation

`helm install` prints `Validation succeeded.` when the values you supplied are internally consistent. That is a check on your values, not on a running agent — the pods still have to start and authenticate.

A healthy default install has one agent pod per node, plus a single `chao` pod:

```shell
kubectl get pods --namespace gremlin
```

```
NAME                READY   STATUS    RESTARTS   AGE
chao-6b9f...        1/1     Running   0          1m
gremlin-4xk2t       1/1     Running   0          1m
gremlin-q7nlv       1/1     Running   0          1m
```

`DESIRED` and `READY` should match on the agent DaemonSet:

```shell
kubectl get daemonset --namespace gremlin -l app.kubernetes.io/name=gremlin
```

With `gremlin.gpu.enabled` the single agent DaemonSet is replaced by one per vendor, so expect several — see [One DaemonSet per vendor](#one-daemonset-per-vendor).

The agent should then appear in the Gremlin app. If a pod never reaches `Running`, or reaches it without the agent showing up, its logs carry the reason — most often a credential or connectivity problem:

```shell
kubectl logs --namespace gremlin -l app.kubernetes.io/name=gremlin
```

## Uninstallation

```shell
helm uninstall gremlin --namespace gremlin
```

`helm uninstall` removes the release and its history. Pass `--keep-history` if you want to retain
the release history for a later rollback.

Uninstalling the release does not delete the namespace. Remove it separately if you no longer need
it:

```shell
kubectl delete namespace gremlin
```

[driverexample]: examples/drivers
