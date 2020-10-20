# Installing Gremlin's PodSecurityPolicy (PSP) with Helm

Clusters with restrictive PSPs will disallow Gremlin behavior unless a suitable policy is granted to the `gremlin` service account.

## Automatically create and use Gremlin's custom PSP

This Helm Chart can create the exact PodSecurityPolicy Gremlin needs when installing with `gremlin.podSecurity.podSecurityPolicy.create=true`.

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin \
    --set      gremlin.podSecurity.podSecurityPolicy.create=true \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=$PATH_TO_CERTIFICATE \
    --set-file gremlin.secret.key=$PATH_TO_PRIVATE_KEY
```