# Gremlin's recommended container drivers

Gremlin has 3 different recommended container drivers: `docker-runc`, `crio-runc`, and `containerd-runc`, each of which
is used to integrate with Docker, Cri-O, and Containerd respectively.

In order to preserve the behaviors of previous versions of this chart, none of the above drivers are enabled by
default. Instead, Gremlin will try to run under the legacy `docker` driver, which has [some limitations][cgroup-driver].

## Requirements

In order to use one of the recommended container drivers, you must run the Gremlin Daemonset in the host's PID namespace,
so `gremlin.hostPID=true`.

## Usage

To use one of the recommended container drivers, set the name in `gremlin.container.driver`

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin \
    --set      gremlin.hostPID=true \
    --set      gremlin.container.driver=crio-runc \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=$PATH_TO_CERTIFICATE \
    --set-file gremlin.secret.key=$PATH_TO_PRIVATE_KEY
```

[cgroup-driver]: https://www.gremlin.com/docs/infrastructure-layer/targets/#supported-cgroup-drivers