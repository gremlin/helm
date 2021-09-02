# Installing Gremlin's SecurityContextConstraint (PSP) with Helm

OpenShift Clusters will disallow Gremlin behavior unless a SCC is granted to the `gremlin` service account.

## Automatically create and use Gremlin's custom SCC

This Helm Chart can create the exact SecurityContextConstraints Gremlin needs when installing with `gremlin.podSecurity.securityContextConstraints.create=true`.

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin \
    --set      gremlin.podSecurity.securityContextConstraints.create=true \
    --set      gremlin.secret.managed=true \
    --set      gremlin.secret.teamID=$GREMLIN_TEAM_ID \
    --set      gremlin.secret.clusterID=$GREMLIN_CLUSTER_ID \
    --set-file gremlin.secret.certificate=$PATH_TO_CERTIFICATE \
    --set-file gremlin.secret.key=$PATH_TO_PRIVATE_KEY
```