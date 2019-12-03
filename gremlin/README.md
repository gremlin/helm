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
| `nodeSelector`                         | Map of node labels for pod assignment                          | `{}`                                                                        |
| `tolerations`                          | List of node taints to tolerate                                | `[]`                                                                        |
| `affinity`                             | Map of node/pod affinities                                     | `{}`                                                                        |
| `gremlin.apparmor`                     | Apparmor profile to set for the Gremlin Daemon                 | `""` (When empty, no profile is set)                                        |
| `gremlin.teamID`                       | Gremlin Team ID to authenticate with                           | `""`                                                                        |
| `gremlin.clusterID`                   | Arbitrary string that uniquely identifies your cluster (e.g. `my-production-cluster`) | `""`                                                                        |
| `gremlin.hostPID`                      | Enable host-level process killing                              | `false`                                                                     |
| `gremlin.hostNetwork`                  | Enable host-level network attacks                              | `false`                                                                     |
| `gremlin.client.secretName`            | Kubernetes secret containing credentials                       | `gremlin-team-cert`                                                         |
| `gremlin.client.cert`                  | Path to the client cert or the cert material base64 encoded    | `file:///var/lib/gremlin/cert/gremlin.cert`                                 |
| `gremlin.client.key`                   | Path to the client key or the key material base64 encoded      | `file:///var/lib/gremlin/cert/gremlin.key`                                  |
| `gremlin.client.certCreateSecret`      | Instruct Helm to create a Secret for storing certs/keys        | `false`                                                                     |
| `gremlin.client.tags`                  | Comma-separated list of custom tags to assign to this client   | `""`                                                                        |
| `gremlin.client.certContent`           | ASCII armored client cert material                             | `""`                                                                        |
| `gremlin.client.keyContent`            | ASCII armored client key material                              | `""`                                                                        |
| `gremlin.installK8sClient`             | Enable kubernetes targeting by installing k8s client           |  true                                                                       |

Specify each parameter using the `--set key=value[,key=value]` argument to
`helm install`.

## Installation

If you don't already have them available, download you team certificates from the Gremlin app. To do so, go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team. Click on the button labelled `Download` next to `Certificates`. If you don't see a button labelled `Download`, click on `Create New` to generate a new certificate.

When you unzip the downloaded file, you will see two files named `TEAM_NAME-client.priv_key.pem` and `TEAM_NAME-client.pub_cert.pem`. Rename these to `gremlin.key` and `gremlin.cert` respectively.

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

