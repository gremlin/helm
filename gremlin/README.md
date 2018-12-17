# Gremlin Client Helm Chart

## Prerequisites

* Kubernetes with extensions/v1beta1 available

## Configuration

By default this chart will install the gremlin client on all nodes in the
cluster.

The following table lists common configurable parameters of the chart and
their default values. See values.yaml for all available options.

|       Parameter                        |           Description                       |                         Default                     |
|----------------------------------------|---------------------------------------------|-----------------------------------------------------|
| `image.pullPolicy`                     | Container pull policy                       | `Always`                                            |
| `image.repository`                     | Container image to use                      | `gremlin/gremlin`                                   |
| `image.tag`                            | Container image tag to deploy               | `latest`                                            |
| `nodeSelector`                         | Map of node labels for pod assignment       | `{}`                                                |
| `tolerations`                          | List of node taints to tolerate             | `[]`                                                |
| `affinity`                             | Map of node/pod affinities                  | `{}`                                                |
| `gremlin.teamID`                       | Gremlin Team ID to authenticate with        | `""`                                                |
| `gremlin.hostPID`                      | Enable host-level process killing           | `false`                                             |
| `gremlin.hostNetwork`                  | Enable host-level network attacks           | `false`                                             |
| `gremlin.client.secretName`            | Kubernetes secret containing credentials    | `gremlin-team-cert`                                 |

Specify each parameter using the `--set key=value[,key=value]` argument to
`helm install`.

## Installation

```shell
helm repo add gremlin https://helm.gremlin.com
helm install --name my-gremlin gremlin/gremlin
```

## Uninstall

```shell
helm delete my-gremlin
```

To delete the deployment and its history:
```shell
helm delete --purge my-gremlin
```
