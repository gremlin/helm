# Gremlin Integrations Client Helm Chart

## Prerequisites

* Kubernetes with apps/v1 available

## Configuration

This chart will install the gremlin integrations client on the specified namespace.

The following table lists common configurable parameters of the chart and their default values. See
values.yaml for all available options.

| Parameter                        | Description                                                                                                                                                                                                                                                                            |                         Default                                           |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `image.pullPolicy`               | Container pull policy                                                                                                                                                                                                                                                                  | `Always`                                                                  |
| `image.pullSecret`               | Pull secret for a private registry                                                                                                                                                                                                                                                     | `""` (When empty, no authentication is used)                              |
| `image.repository`               | Container image to use                                                                                                                                                                                                                                                                 | `gremlin/gremlin-integrations`                                                         |
| `image.tag`                      | Container image tag to deploy                                                                                                                                                                                                                                                          | `latest`                                                                  |
| `nodeSelector`                   | Map of node labels for pod assignment for the `gremlin-integrations` container                                                                                                                                                                                                         | `{}`                                                                      |
| `tolerations`                    | List of node taints to tolerate for the `gremlin-integrations` container                                                                                                                                                                                                               | `[]`                                                                      |
| `affinity`                       | Map of node/pod affinities for the `gremlin-integrations` container                                                                                                                                                                                                                    | `{}`                                                                      |
| `gremlin.serviceAccount.create`  | Specifies whether Gremlin's kubernetes service account should be created by this helm chart                                                                                                                                                                                            | `true` | 
| `gremlin.serviceUrl`             | Specifies the Control Plane endpoint URL                                                                                                                                                                                                                                               | `https://api.gremlin.com/v1` | 
| `gremlin.allowList`              | Whitelist URLs in order to allow access only to specific set of endpoints                                                                                                                                                                                                              | `""` | 
| `gremlin.secret.managed`         | Specifies whether Gremlin should manage its secrets with Helm                                                                                                                                                                                                                          | `false`                                                                   |
| `gremlin.secret.type`            | The type of certificate to use, can be either `certificate` or `secret`                                                                                                                                                                                                                | `certificate`                                                    |
| `gremlin.secret.name`            | The name of certificate to use, like in the case of pointing to an eternally managed secret                                                                                                                                                                                            | `gremlin-team-cert`                          |
| `gremlin.secret.teamID`          | Gremlin Team ID to authenticate with                                                                                                                                                                                                                                                   | `""`                                                                      |
| `gremlin.secret.certificate`     | Contents of the certificate. Required if using managed secrets of `type=certificate`                                                                                                                                                                                                   | `""`                                               |
| `gremlin.secret.key`             | Contents of the private key. Required if using managed secrets of `type=certificate`                                                                                                                                                                                                   | `""`                                               |
| `gremlin.secret.teamSecret`      | Gremlin's team secret. Required if using managed secrets of `type=secret`                                                                                                                                                                                                              | `""`                                                          |
| `gremlin.resources`              | Set resource requests and limits                                                                                                                                                                                                                                                       | `{}`
| `gremlin.proxy.url`              | Specifies the http proxy the agent should use to communicate with api.gremlin.com.                                                                                                                                                                                                     |  `""` (ignored) |                                        |
| `ssl.certFile`                   | Add a certificate file to Gremlin's set of certificate authorities. This argument expects a file containing the certificate(s) you wish to add. When set, this chart creates secret (`integrations-ssl-cert-file`) with the file contents. This value is ignored when blank or absent. |  `""` (ignored) |
| `ssl.certDir`                    | sets the SSL_CERT_DIR environment variable on the both agents. Unlike ssl.certFile, this value accepts only a path to an existing directory on the Kubernetes nodes. This value is ignored when blank or absent.                                                                       |  `""` (ignored) | 

Specify each parameter using the `--set[-file] key=value[,key=value]` argument to `helm install`.

**Example Usage**

```shell
$ helm install gremlin-integrations gremlin/gremlin-integrations \
  --set       gremlin.secret.managed=true \
  --set       gremlin.secret.type=certificate \
  --set       gremlin.secret.teamID=$GREMLIN_TEAM_ID \
  --set-file  gremlin.secret.certificate=/path/to/gremlin.cert \
  --set-file  gremlin.secret.key=/path/to/gremlin.key \
  --set       'tolerations[0].effect=NoSchedule' \
  --set       'tolerations[0].key=node-role.kubernetes.io/master' \
  --set       'tolerations[0].operator=Exists'
```

_note_: Depending on your shell you may need different quoting around `tolerations[0]`

## Installation

All Gremlin Integrations installations require authentication with our Gremlin control plane. There
are two types of authentication available to Gremlin and Helm: `certificate`, and `secret`. You can
find out more about these authentication
types [here](https://www.gremlin.com/docs/infrastructure-layer/authentication/).

For this Helm chart, you'll need to download your team certificate or team secret from the Gremlin
app.

**Certificate**

1. go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team, and
   then `Configuration`
2. Click on the button labeled `Download` next to `Certificates` (If you don't see a button
   labelled `Download`, click on `Create New` to generate a new certificate)
3. When you unzip the downloaded file, you will see two files named `TEAM_NAME-client.priv_key.pem`
   and `TEAM_NAME-client.pub_cert.pem`. Rename these to `gremlin.key` and `gremlin.cert`
   respectively. These will be refered to as `/path/to/gremlin.cert` and `/path/to/gremlin.key` in
   later instructions.

**Secret**

1. go to [Company Settings](https://app.gremlin.com/settings/teams), and select your team, and
   then `Configuration`
2. Click on the button labeled `New` next to `Secret Key` (If you don't see a button labeled `New`,
   it's already been created. Talk to your administrator who should have the key or click
   the `Reset` button to create a new one)
3. You should see a value named `GREMLIN_TEAM_SECRET`, this will be refered to
   as `$GREMLIN_TEAM_SECRET` in later instructions

### With Managed Secrets

Some find it preferable to have this chart manage Gremlin's secret values instead of administrating
them outside of Helm.

#### For certificate auth

```shell
helm install gremlin-integrations gremlin/gremlin-integrations \
    --namespace gremlin \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key
```

#### For secret auth

```shell
helm install gremlin-integrations gremlin/gremlin-integrations \
    --namespace gremlin \
    --set gremlin.secret.managed=true \
    --set gremlin.secret.type=secret \
    --set gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set gremlin.secret.teamSecret=$GREMLIN_TEAM_SECRET
```

### Without Managed Secrets

If you do not want this Chart to manage the kubernetes secrets for Gremlin, point this chart to your
external secret with `gremlin.secret.name` and `gremlin.secret.type`

##### For secret auth

Create the external secret

```shell
kubectl create secret generic gremlin-team-secret \
    --namespace gremlin \
    --from-literal=GREMLIN_TEAM_ID=$GREMLIN_TEAM_ID \
    --from-literal=GREMLIN_TEAM_SECRET=$GREMLIN_TEAM_SECRET \
```

Install the Helm chart

```shell
helm install gremlin-integrations gremlin/gremlin-integrations \
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
    --from-file=gremlin.cert=/path/to/gremlin.cert \
    --from-file=gremlin.key=/path/to/gremlin.key
```

```shell
helm install gremlin-integrations gremlin/gremlin-integrations \
    --namespace gremlin \
    --set gremlin.secret.name=gremlin-team-cert
```

### With an HTTP_PROXY

Gremlin can be configured to communicate with api.gremlin.com through an http_proxy. You can set
this proxy with `gremlin.proxy.url`.

```shell
helm install gremlin-integrations gremlin/gremlin-integrations \
    --namespace gremlin \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key \
    --set      gremlin.proxy.url=http://proxy.net:3128
```

#### HTTPS_PROXY with custom certificate authority

```shell
helm install gremlin-integrations gremlin/gremlin \
    --namespace gremlin \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set-file gremlin.secret.certificate=/path/to/gremlin.cert \
    --set-file gremlin.secret.key=/path/to/gremlin.key \
    --set      gremlin.proxy.url=https://proxy.net:3128 \
    --set-file ssl.certFile=$HOME/Workspace/proxy/ca.pem
```

## Uninstallation

```shell
helm delete gremlin-integrations
```

To delete the deployment and its history:

```shell
helm delete --purge gremlin-integrations
```