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
| `image.repository`                     | Container image to use                                         | `gremlin/gremlin`                                                           |
| `image.tag`                            | Container image tag to deploy                                  | `latest`                                                                    |
| `chaoimage.pullPolicy`                 | Container pull policy for the `chao` container                 | `Always`                                                                    |
| `chaoimage.repository`                 | Container image to use for the `chao` container                | `gremlin/chao`                                                              |
| `chaoimage.tag`                        | Container image tag to deploy for the `chao` container         | `latest`                                                                    |
| `nodeSelector`                         | Map of node labels for pod assignment                          | `{}`                                                                        |
| `tolerations`                          | List of node taints to tolerate                                | `[]`                                                                        |
| `affinity`                             | Map of node/pod affinities                                     | `{}`                                                                        |
| `gremlin.apparmor`                     | Apparmor profile to set for the Gremlin Daemon                 | `""` (When empty, no profile is set)                                        |
| `gremlin.secret.managed`               | Specifies whether Gremlin should manage its secrets with Helm  | `false`                                                                     |
| `gremlin.secret.type`                  | The type of certificate to use, can be either `certificate` or `secret` | `certificate`                                                      |
| `gremlin.secret.name`                  | The name of certificate to use, like in the case of pointing to an eternally managed secret | `gremlin-team-cert`                            |
| `gremlin.secret.teamID`                | Gremlin Team ID to authenticate with                           | `""`                                                                        |
| `gremlin.secret.clusterID`             | Arbitrary string that uniquely identifies your cluster (e.g. `my-production-cluster`) | `""`                                                 |
| `gremlin.secret.certificate`           | Contents of the certificate. Required if using managed secrets of `type=certificate`  | `""`                                                 |
| `gremlin.secret.key`                   | Contents of the private key. Required if using managed secrets of `type=certificate`  | `""`                                                 |
| `gremlin.secret.teamSecret`            | Gremlin's team secret. Required if using managed secrets of `type=secret`  | `""`                                                            |
| `gremlin.hostPID`                      | Enable host-level process killing                              | `false`                                                                     |
| `gremlin.hostNetwork`                  | Enable host-level network attacks                              | `false`                                                                     |
| `gremlin.client.tags`                  | Comma-separated list of custom tags to assign to this client   | `""`                                                                        |
| `gremlin.installK8sClient`             | Enable kubernetes targeting by installing k8s client           |  true                                                                       |

Specify each parameter using the `--set[-file] key=value[,key=value]` argument to `helm install`.

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
helm install gremlin/gremlin \
    --name gremlin \
    --namespace gremlin \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key
```

#### For secret auth

```shell
helm install gremlin/gremlin \
    --name gremlin \
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
helm install gremlin/gremlin \
    --name gremlin \
    --set gremlin.secret.name=gremlin-team-secret \
    --set gremlin.secret.type=secret # Default is gremlin.secret.type=certificate
```

#### For certificate auth

Create the external secret

```shell
kubectl create secret generic gremlin-team-cert \
    --namespace gremlin \
    --from-file=gremlin.cert=/path/to/gremlin.cert \
    --from-file=gremlin.key=/path/to/gremlin.key
```

```shell
helm install gremlin/gremlin \
    --name gremlin \
    --set gremlin.secret.name=gremlin-team-cert
```

## Uninstallation

```shell
helm delete gremlin
```

To delete the deployment and its history:
```shell
helm delete --purge gremlin
```

