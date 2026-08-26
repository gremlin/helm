# Gremlin Client Helm Chart

## Prerequisites

* Kubernetes with apps/v1 available
* Helm 3. The uninstall instructions below use Helm 3 syntax.
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

|       Parameter                        |           Description                                          | Default                                                                                     |
|----------------------------------------|----------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `image.pullPolicy`                     | Container pull policy                                          | `Always`                                                                                    |
| `image.pullSecret`                     | Pull secret for a private registry                             | `""` (When empty, no authentication is used)                                                |
| `image.repository`                     | Container image to use                                         | `gremlin/gremlin`                                                                           |
| `image.tag`                            | Container image tag to deploy                                  | `latest`                                                                                    |
| `chaoimage.pullPolicy`                 | Container pull policy for the `chao` container                 | `Always`                                                                                    |
| `chaoimage.pullSecret`                 | Pull secret for a private registry for the `chao` container    | `""` (When empty, no authentication is used)                                                |
| `chaoimage.repository`                 | Container image to use for the `chao` container                | `gremlin/chao`                                                                              |
| `chaoimage.tag`                        | Container image tag to deploy for the `chao` container         | `latest`                                                                                    |
| `nodeSelector`                         | Map of node labels for pod assignment for the `gremlin` container | `{}`                                                                                        |
| `tolerations`                          | List of node taints to tolerate for the `gremlin` container    | `[]`                                                                                        |
| `affinity`                             | Map of node/pod affinities for the `gremlin` container         | `{}`                                                                                        |
| `chao.podLabels`                       | Kubernetes labels applied to the chao deployment and it's Pods | `{}`                                                                                        |
| `chao.priorityClassName`               | The name of the priority class to use for the Chao deployment  | `""`                                                                                        |
| `chao.nodeSelector`                    | Map of node labels for pod assignment for the `chao` container | `{}`                                                                                        |
| `chao.tolerations`                     | List of node taints to tolerate for the `chao` container       | `[]`                                                                                        |
| `chao.affinity`                        | Map of node/pod affinities for the `chao` container            | `{}`                                                                                        |
| `chao.create`                          | Enable kubernetes targeting by installing k8s client           | true                                                                                        |
| `chao.resources`                       | Set resource requests and limits for the chao deployment       | `{}`                                                                                        |
| `chao.extraEnv`                        | Specify any arbitrary environment variables to pass to the Chao deployment. | `[]`                                                                                        |
| `chao.namespaces`                      | List of namespaces for Gremlin to watch for attacking          | `[]`                                                                                        
| `gremlin.podLabels`           | Kubernetes labels applied to the Gremlin Agent's DaemonSet and it's pods| `{}`                                                                                        |
| `gremlin.apparmor`                     | Apparmor profile to set for the Gremlin Daemon                 | `""` (When empty, no profile is set)                                                        |
| `gremlin.installApparmorProfile`       | Have Gremlin install their own [Apparmor Profile](agent_apparmor.profile) (NOTE: `gremlin.apparmor` overrides this) | `false`                                                                                     |
| `gremlin.container.driver`             | Specifies which container driver with which to run Gremlin. [See example][driverexample] | `linux` (`any` is an accepted alias with identical behaviour)                                |
| `gremlin.cgroup.root`                  | Specifies the absolute path for the cgroup controller root on target host systems | `/sys/fs/cgroup`                                                                            |
| `gremlin.serviceAccount.create`        | Specifies whether Gremlin's kubernetes service account should be created by this helm chart | `true`                                                                                      |
| `gremlin.podSecurity.allowPrivilegeEscalation` | Allows Gremlin containers privilege escalation powers  | `false`                                                                                     |
| `gremlin.podSecurity.capabilities`     | Specifies which Linux capabilities should be granted to Gremlin| `[KILL, NET_ADMIN, SYS_BOOT, SYS_TIME, DAC_READ_SEARCH, SYS_RESOURCE, SYS_ADMIN, SYS_PTRACE, NET_RAW]` |
| `gremlin.podSecurity.seLinuxOptions`   | Specifies SELinux options to apply to the Gremlin Daemonset container securityContext. WARNING: This option should be enabled with caution as it is likely to break the GremlinAgent or your Kubernetes installation. Gremlin recommends users instead install a custom SELinux policy that provides integration with the labels already defined on the target system so that paths do not need to be relabeled. See https://github.com/gremlin/selinux-policies | `""`                                                                                        |
| `gremlin.podSecurity.readOnlyRootFilesystem` | Forces the Gremlin Daemonset containers to run with a read-only root filesystem | `false`                                                                                     |
| `gremlin.podSecurity.supplementalGroups.rule` | Specifies the Linux groups the Gremlin Daemonset containers should run as | `RunAsAny`                                                                                  |
| `gremlin.podSecurity.fsGroup.rule`     | Specifies the Linux groups applied to mounted volumes          | `RunAsAny`                                                                                  |
| `gremlin.podSecurity.volumes`          | Specifies the volume types the Gremlin Daemonset is allowed to use | `[configMap, secret, hostPath, emptyDir]`                                                             |
| `gremlin.podSecurity.podSecurityPolicy.create` | When true, Gremlin creates and uses a custom PodSecurityPolicy, granting all behaviors Gremlin needs | `false`                                                                                     |
| `gremlin.podSecurity.podSecurityPolicy.seLinux` | Sets the SecurityContext for the PSP used by the Gremlin Daemonset | `{ rule: MustRunAs, seLinuxOptions: { type: gremlin.process } }`                            |
| `gremlin.podSecurity.podSecurityPolicy.runAsUser.rule`   | Specifies the Linux user the Gremlin Daemonset containers should run as | `RunAsAny`                                                                                  |
| `gremlin.podSecurity.securityContextConstraints.create` | When true, Gremlin creates and uses a custom SecurityContextConstraints, granting all behaviors Gremlin needs | `false`                                                                                     |
| `gremlin.podSecurity.securityContextConstraints.allowHostDirVolumePlugin` | Specifies whether the Gremlin Daemonset has access to host path directories as mounted volumes | `true`                                                                                      |
| `gremlin.podSecurity.securityContextConstraints.seLinuxContext` | Sets the SecurityContext for the SCC used by the Gremlin Daemonset | `{ type: MustRunAs, seLinuxOptions: { type: spc_t, level: s0-s0:c0.c1023 } }`                 |
| `gremlin.podSecurity.securityContextConstraints.runAsUser.type`   | Specifies the Linux user the Gremlin Daemonset containers should run as | `RunAsAny`                                                                                  |
| `gremlin.podSecurity.privileged`       | Determines whether the Gremlin Daemonset should run privileged containers | `false`                                                                                     |
| `gremlin.podSecurity.seccomp.enabled`  | Determines whether the Gremlin Daemonset should be annotated with the seccomp profile | `false`                                                                                     |
| `gremlin.podSecurity.seccomp.profile`  | Describes the name of the seccomp profile to use               | `localhost/gremlin`                                                                         |
| `gremlin.secret.managed`               | Specifies whether Gremlin should manage its secrets with Helm  | `false`                                                                                     |
| `gremlin.secret.type`                  | The type of certificate to use, can be either `certificate` or `secret` | `certificate`                                                                               |
| `gremlin.serviceUrl`                   | Base URL of the Gremlin API the agent and Chao report to. The values file generated at https://app.gremlin.com/getting-started always sets this explicitly, so you rarely need to change it; override it for Gremlin Private Edition | `https://api.gremlin.com/v1`                                                                 |
| `gremlin.secret.name`                  | Name of the Secret holding the credentials, for example when pointing at an externally managed secret | `gremlin-team-cert` when `gremlin.secret.managed=false`, `gremlin-secret` when `true`        |
| `gremlin.secret.teamID`                | Gremlin Team ID to authenticate with                           | `""`                                                                                        |
| `gremlin.secret.clusterID`             | Arbitrary string that uniquely identifies your cluster (e.g. `my-production-cluster`) | `""`                                                                                        |
| `gremlin.secret.certificate`           | Contents of the certificate. Required if using managed secrets of `type=certificate`  | `""`                                                                                        |
| `gremlin.secret.key`                   | Contents of the private key. Required if using managed secrets of `type=certificate`  | `""`                                                                                        |
| `gremlin.secret.teamSecret`            | Gremlin's team secret. Required if using managed secrets of `type=secret`  | `""`                                                                                        |
| `gremlin.resources`                    | Set resource requests and limits                               | `{}`                                                                                        |
| `gremlin.dnsPolicy`                    | The DNS policy to use for the Gremlin DaemonSet                | `ClusterFirstWithHostNet`                                                                   |
| `gremlin.hostPID`                      | Enable host-level process killing                              | `true`                                                                                      |
| `gremlin.hostNetwork`                  | Enable host-level network attacks                              | `true`                                                                                      |
| `gremlin.priorityClassName`            | The priority class to use for the agent DaemonSet              | `""`                                                                                        |
| `gremlin.client.tags`                  | Comma-separated list of `key=value` tag pairs to assign to this client. Commas must be backslash-escaped when using `--set`; see [Example Usage](#example-usage) | `""`                                                                                        |
| `gremlin.proxy.url`                    | Specifies the http proxy the agent should use to communicate with api.gremlin.com. | `""` (ignored)                                                                              |                                       |
| `gremlin.extraEnv`                     | Specify any arbitrary environment variables to pass to the Gremlin Agent daemonset. | `[]`                                                                                        |
| `gremlin.features.discoverDestinationService.enabled` | Enable discovery of a destination service in a service mesh to resolve hostnames | `false`                                                                |
| `gremlin.gpu.enabled`                  | Expose host GPU/OpenCL drivers to the agent for the GPU attack | `false`                                                                                     |
| `gremlin.gpu.cdiDevice`                | CDI device to inject via pod annotation (for CDI-based runtimes) | `""`                                                                                        |
| `gremlin.gpu.projectOpenclIcd`         | Project a vendor's OpenCL ICD registry file into the container  | `true`                                                                             |
| `gremlin.gpu.vendors`                  | Vendor blocks to target; one DaemonSet is created per entry     | `[nvidia, amd]`                                                                             |
| `gremlin.gpu.<vendor>`                 | Per-vendor config block: `nodeSelector`, `runtimeClassName`, `env`, `volumes`, `volumeMounts`, `openclIcd` | see `values.yaml`                                  |
| `ssl.certFile`                         | Add a certificate file to Gremlin's set of certificate authorities. This argument expects a file containing the certificate(s) you wish to add. When set, this chart creates secret (`ssl-cert-file`) with the contents and passes it to both agents. This value is ignored when blank or absent. | `""` (ignored)                                                                              |
| `ssl.certDir`                          | sets the SSL_CERT_DIR environment variable on the both agents. Unlike ssl.certFile, this value accepts only a path to an existing directory on the Kubernetes nodes. This value is ignored when blank or absent. | `""` (ignored)                                                                              |

Specify each parameter using the `--set[-file] key=value[,key=value]` argument to `helm install`.

**Example Usage**
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

## Installation

All Gremlin installations require authentication with our Gremlin control plane. There are two types of authentication available to Gremlin and Helm: `certificate`, and `secret`. You can find out more about these authentication types [here](https://www.gremlin.com/docs/infrastructure-layer/authentication/).

For this Helm chart, you'll need to download your team certificate or team secret from the Gremlin app.

**Certificate**
1. go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team, and then `Configuration`
2. Click on the button labeled `Download` next to `Certificates` (If you don't see a button labelled `Download`, click on `Create New` to generate a new certificate)
3. When you unzip the downloaded file, you will see two files named `TEAM_NAME-client.priv_key.pem` and `TEAM_NAME-client.pub_cert.pem`. Rename these to `gremlin.key` and `gremlin.cert` respectively. These will be refered to as `/path/to/gremlin.cert` and `/path/to/gremlin.key` in later instructions.

**Secret**
1. go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team, and then `Configuration`
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
