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
| `gremlin.hostPID`                      | Enable host-level process killing                              | `false`                                                                     |
| `gremlin.hostNetwork`                  | Enable host-level network attacks                              | `false`                                                                     |
| `gremlin.client.secretName`            | Kubernetes secret containing credentials                       | `gremlin-team-cert`                                                         |
| `gremlin.client.cert`                  | Path to the client cert or the cert material base64 encoded    | `file:///var/lib/gremlin/cert/gremlin.cert`                                 |
| `gremlin.client.key`                   | Path to the client key or the key material base64 encoded      | `file:///var/lib/gremlin/cert/gremlin.key`                                  |
| `gremlin.client.certCreateSecret`                   | Instruct Helm to create a Secret for storing certs/keys      | `false`                                  |
| `gremlin.client.tags`                  | Comma-separated list of custom tags to assign to this client   | `""`
| `gremlin.client.certContent`                   | ASCII armored client cert material      | `""`                                  |
| `gremlin.client.keyContent`                   | ASCII armored client key material      | `""`                                  |


Specify each parameter using the `--set key=value[,key=value]` argument to
`helm install`.

## Installation

If you don't already have them available, download you team certificates from the Gremlin app. To do so, go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team. Click on the button labelled `Download` next to `Certificates`. If you don't see a button labelled `Download`, click on `Create New` to generate a new certificate.

When you unzip the downloaded file, you will see two files named `TEAM_NAME-client.priv_key.pem` and `TEAM_NAME-client.pub_cert.pem`. Rename these to `gremlin.key` and `gremlin.cert` respectively.

### Deploying with a manually created Kubernetes Secret

```shell
kubectl create secret generic gremlin-team-cert --from-file=./gremlin.cert --from-file=./gremlin.key
```

Once your secret is created, install this chart with Helm:

```shell
helm repo add gremlin https://helm.gremlin.com
helm install --name my-gremlin gremlin/gremlin
```

### Deploying with a Helm created Kubernetes Secret

```shell
helm repo add gremlin https://helm.gremlin.com
helm install --name my-gremlin gremlin/gremlin --set gremlin.client.certCreateSecret=true --set-file gremlin.client.certContent=gremlin.cert --set-file gremlin.client.keyContent=gremlin.key
```

## Uninstall

```shell
helm delete my-gremlin
```

To delete the deployment and its history:
```shell
helm delete --purge my-gremlin
```
