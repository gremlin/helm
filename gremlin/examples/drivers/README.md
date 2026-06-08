# Gremlin's recommended container drivers

Gremlin has 3 different recommended container drivers: `docker-linux`, `crio-linux`, and `containerd-linux`, each of which
is used to integrate with Docker, Cri-O, and Containerd respectively.

You also have the option of specifying `any` which will mount the locations for all supported drivers and then gremlin
will attempt to determine the correct one.  This can be a good option if you don't know which driver you have. 

## Requirements

In order to use one of the recommended container drivers, you must run the Gremlin Daemonset in the host's PID and network namespaces: `gremlin.hostPID=true`, and `gremlin.hostNetwork=true`. These are both `true` by default.

## Usage

To use one of the recommended container drivers, set the name in `gremlin.container.driver`

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin \
    --set      gremlin.hostPID=true \
    --set      gremlin.container.driver=crio-linux \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=$PATH_TO_CERTIFICATE \
    --set-file gremlin.secret.key=$PATH_TO_PRIVATE_KEY
```

[cgroup-driver]: https://www.gremlin.com/docs/infrastructure-layer/targets/#supported-cgroup-drivers
