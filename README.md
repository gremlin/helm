# Gremlin Helm Charts

This repository hosts the official **Gremlin Helm Charts** to deploy **Gremlin** products to [Kubernetes](https://kubernetes.io/)

## Install Helm

Get the latest [Helm release](https://github.com/kubernetes/helm#install).

## Install Charts

Add this Chart repo to Helm, and install:

```console
helm repo add gremlin https://helm.gremlin.com/
helm install gremlin gremlin/gremlin \
    --namespace gremlin \
    --set gremlin.secret.managed=true \
    --set gremlin.secret.type=secret \
    --set gremlin.secret.teamID=YOUR-TEAM-ID \
    --set gremlin.secret.clusterID=YOUR-CLUSTER-ID \
    --set gremlin.secret.teamSecret=YOUR-TEAM-SECRET
```

For more detailed instructions, see the chart's documentation [here](https://github.com/gremlin/helm/blob/master/gremlin/README.md).

## Reporting Issues

Please report all issues via github issues [here](https://github.com/gremlin/helm/issues).
