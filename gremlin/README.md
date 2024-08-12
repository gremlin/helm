# Gremlin Client Helm Chart

## Prerequisites

* Kubernetes with apps/v1 available

## Configuration

By default this chart will install the gremlin client on all nodes in the
cluster.

The following table lists common configurable parameters of the chart and
their default values. See values.yaml for all available options.

|       Parameter                        |           Description                                          |                         Default                                             |
|----------------------------------------|----------------------------------------------------------------|-----------------------------------------------------------------------------|
| `image.pullPolicy`                     | Container pull policy                                          | `Always`                                                                    |
| `image.pullSecret`                     | Pull secret for a private registry                             | `""` (When empty, no authentication is used)                                |
| `image.repository`                     | Container image to use                                         | `gremlin/gremlin`                                                           |
| `image.tag`                            | Container image tag to deploy                                  | `latest`                                                                    |
| `chaoimage.pullPolicy`                 | Container pull policy for the `chao` container                 | `Always`                                                                    |
| `chaoimage.pullSecret`                 | Pull secret for a private registry for the `chao` container    | `""` (When empty, no authentication is used)                                |
| `chaoimage.repository`                 | Container image to use for the `chao` container                | `gremlin/chao`                                                              |
| `chaoimage.tag`                        | Container image tag to deploy for the `chao` container         | `latest`                                                                    |
| `nodeSelector`                         | Map of node labels for pod assignment for the `gremlin` container | `{}`                                                                        |
| `tolerations`                          | List of node taints to tolerate for the `gremlin` container    | `[]`                                                                        |
| `affinity`                             | Map of node/pod affinities for the `gremlin` container         | `{}`                                                                        |
| `chao.clientId`                        | An identifier for this specific client.  Leaving this blank will generate a random one | `""`                                                                          |
| `chao.podLabels`                       | Kubernetes labels applied to the chao deployment and it's Pods | `{}`                                                                        |
| `chao.priorityClassName`               | The name of the priority class to use for the Chao deployment  | `""`                                                                        |
| `chao.nodeSelector`                    | Map of node labels for pod assignment for the `chao` container | `{}`                                                                        |
| `chao.tolerations`                     | List of node taints to tolerate for the `chao` container       | `[]`                                                                        |
| `chao.affinity`                        | Map of node/pod affinities for the `chao` container            | `{}`                                                                        |
| `chao.create`                          | Enable kubernetes targeting by installing k8s client           |  true                                                                       |
| `chao.extraEnv`                        | Specify any arbitrary environment variables to pass to the Chao deployment. | `[]`                                                           |
| `gremlin.podLabels`           | Kubernetes labels applied to the Gremlin Agent's DaemonSet and it's pods| `{}`                                                                        |
| `gremlin.apparmor`                     | Apparmor profile to set for the Gremlin Daemon                 | `""` (When empty, no profile is set)                                        |
| `gremlin.installApparmorProfile`       | Have Gremlin install their own [Apparmor Profile](agent_apparmor.profile) (NOTE: `gremlin.apparmor` overrides this) | `false` |
| `gremlin.container.driver`             | Specifies which container driver with which to run Gremlin. [See example][driverexample] | `docker` |
| `gremlin.cgroup.root`                  | Specifies the absolute path for the cgroup controller root on target host systems | `/sys/fs/cgroup` |
| `gremlin.serviceAccount.create`        | Specifies whether Gremlin's kubernetes service account should be created by this helm chart | `true` |
| `gremlin.podSecurity.allowPrivilegeEscalation` | Allows Gremlin containers privilege escalation powers  | `false` |
| `gremlin.podSecurity.capabilities`     | Specifies which Linux capabilities should be granted to Gremlin| `[KILL, NET_ADMIN, SYS_BOOT, SYS_TIME, SYS_ADMIN, SYS_PTRACE, SETFCAP, AUDIT_WRITE, MKNOD]` |
| `gremlin.podSecurity.seLinuxOptions`   | Specifies SELinux options to apply to the Gremlin Daemonset container securityContext. WARNING: This option should be enabled with caution as it is likely to break the GremlinAgent or your Kubernetes installation. Gremlin recommends users instead install a custom SELinux policy that provides integration with the labels already defined on the target system so that paths do not need to be relabeled. See https://github.com/gremlin/selinux-policies | `""` |
| `gremlin.podSecurity.readOnlyRootFilesystem` | Forces the Gremlin Daemonset containers to run with a read-only root filesystem | `false` |
| `gremlin.podSecurity.supplementalGroups.rule` | Specifies the Linux groups the Gremlin Daemonset containers should run as | `RunAsAny` |
| `gremlin.podSecurity.fsGroup.rule`     | Specifies the Linux groups applied to mounted volumes          | `RunAsAny` |
| `gremlin.podSecurity.volumes`          | Specifies the volume types the Gremlin Daemonset is allowed to use | `[configMap, secret, hostPath]` |
| `gremlin.podSecurity.podSecurityPolicy.create` | When true, Gremlin creates and uses a custom PodSecurityPolicy, granting all behaviors Gremlin needs | `false` |
| `gremlin.podSecurity.podSecurityPolicy.seLinux` | Sets the SecurityContext for the PSP used by the Gremlin Daemonset | `{ rule: MustRunAs, seLinuxOptions: { type: gremlin.process } }` |
| `gremlin.podSecurity.podSecurityPolicy.runAsUser.rule`   | Specifies the Linux user the Gremlin Daemonset containers should run as | `RunAsAny` |
| `gremlin.podSecurity.securityContextConstraints.create` | When true, Gremlin creates and uses a custom SecurityContextConstraints, granting all behaviors Gremlin needs | `false` |
| `gremlin.podSecurity.securityContextConstraints.allowHostDirVolumePlugin` | Specifies whether the Gremlin Daemonset has access to host path directories as mounted volumes | `true` |
| `gremlin.podSecurity.securityContextConstraints.seLinuxContext` | Sets the SecurityContext for the SCC used by the Gremlin Daemonset | `{ type: MustRunAs, seLinuxOptions: { type: gremlin.process } }` |
| `gremlin.podSecurity.securityContextConstraints.runAsUser.type`   | Specifies the Linux user the Gremlin Daemonset containers should run as | `RunAsAny` |
| `gremlin.podSecurity.privileged`       | Determines whether the Gremlin Daemonset should run privileged containers | `false` |
| `gremlin.podSecurity.seccomp.enabled`  | Determines whether the Gremlin Daemonset should be annotated with the seccomp profile | `false` |
| `gremlin.podSecurity.seccomp.profile`  | Describes the name of the seccomp profile to use               | `localhost/gremlin` |
| `gremlin.secret.managed`               | Specifies whether Gremlin should manage its secrets with Helm  | `false`                                                                     |
| `gremlin.secret.type`                  | The type of certificate to use, can be either `certificate` or `secret` | `certificate`                                                      |
| `gremlin.secret.name`                  | The name of certificate to use, like in the case of pointing to an eternally managed secret | `gremlin-team-cert`                            |
| `gremlin.secret.teamID`                | Gremlin Team ID to authenticate with                           | `""`                                                                        |
| `gremlin.secret.clusterID`             | Arbitrary string that uniquely identifies your cluster (e.g. `my-production-cluster`) | `""`                                                 |
| `gremlin.secret.certificate`           | Contents of the certificate. Required if using managed secrets of `type=certificate`  | `""`                                                 |
| `gremlin.secret.key`                   | Contents of the private key. Required if using managed secrets of `type=certificate`  | `""`                                                 |
| `gremlin.secret.teamSecret`            | Gremlin's team secret. Required if using managed secrets of `type=secret`  | `""`                                                            |
| `gremlin.resources`                    | Set resource requests and limits                               | `{}`                                                                        |
| `gremlin.hostPID`                      | Enable host-level process killing                              | `true`                                                                     |
| `gremlin.hostNetwork`                  | Enable host-level network attacks                              | `true`                                                                     |
| `gremlin.priorityClassName`            | The priority class to use for the agent DaemonSet              | `""`                                                                     |
| `gremlin.client.tags`                  | Comma-separated list of custom tags to assign to this client   | `""`                                                                        |
| `gremlin.proxy.url`                    | Specifies the http proxy the agent should use to communicate with api.gremlin.com. |  `""` (ignored) |                                       |
| `gremlin.extraEnv`                     | Specify any arbitrary environment variables to pass to the Gremlin Agent daemonset. | `[]`                                                   |
| `ssl.certFile`                         | Add a certificate file to Gremlin's set of certificate authorities. This argument expects a file containing the certificate(s) you wish to add. When set, this chart creates secret (`ssl-cert-file`) with the contents and passes it to both agents. This value is ignored when blank or absent. |  `""` (ignored) |
| `ssl.certDir`                          | sets the SSL_CERT_DIR environment variable on the both agents. Unlike ssl.certFile, this value accepts only a path to an existing directory on the Kubernetes nodes. This value is ignored when blank or absent. |  `""` (ignored) |

Specify each parameter using the `--set[-file] key=value[,key=value]` argument to `helm install`.

**Example Usage**
```
$ helm install gremlin gremlin/gremlin \
  --set       gremlin.client.tags="k8s,kubernetes" \
  --set       gremlin.clusterID=my-cluster \
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
    --namespace gremlin \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key
```

#### For secret auth

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin \
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
    --namespace gremlin \
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
    --namespace gremlin \
    --set gremlin.secret.name=gremlin-team-cert
```

### With an HTTP_PROXY

Gremlin can be configured to communicate with api.gremlin.com through an http_proxy. You can set this proxy with `gremlin.proxy.url`.

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin \
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
    --namespace gremlin \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key \
    --set      gremlin.proxy.url=https://proxy.net:3128 \
    --set-file ssl.certFile=$HOME/Workspace/proxy/ca.pem
```

## Uninstallation

```shell
helm delete gremlin
```

To delete the deployment and its history:
```shell
helm delete --purge gremlin
```

[driverexample]: examples/drivers
