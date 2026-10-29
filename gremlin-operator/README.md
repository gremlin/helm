# Gremlin Operator Helm Chart

This chart installs the Gremlin Kubernetes Operator: the reconciler and the credential manager, each as its own
Deployment, with the Gremlin CRDs and the RBAC they need. The operator then deploys and manages Gremlin agents for each
`Agent` resource you create.

## Prerequisites

* Helm 3
* Adding the Gremlin helm repo. `helm repo add gremlin https://helm.gremlin.com/ && helm repo update`
* Permission to create cluster-scoped resources: the CRDs, ClusterRoles and ClusterRoleBindings.
* Only one operator install per cluster works: the CRDs, ClusterRoles and the names `gremlin-system`, `gremlin-agent`
  and `gremlin-chao` are cluster-wide or fixed by the operator.

## Install

```shell
helm install gremlin-operator gremlin/gremlin-operator \
    --namespace gremlin-operator-system --create-namespace
```

The chart goes into the release namespace (`gremlin-operator-system` above), where both Deployments run. Use a
dedicated namespace: the chart refuses `default`, `gremlin-system` and any `kube-` or `openshift-` namespace. See
[Trust boundaries](#trust-boundaries). It also
creates the install namespace `gremlin`, where the operator deploys agents, and the credential namespace
`gremlin-system`.

Object names start with `gremlin-operator-` whatever the release is called, because the operator and its documentation
refer to them by name. `fullnameOverride` and `nameOverride` change the prefix. Changing `nameOverride` while `fullnameOverride` is set changes
the Deployments' selector, which Kubernetes does not allow to change, so the upgrade fails.

## Configuration

The following table lists the configurable parameters of the chart and their default values. Every setting that
configures one process's pod is in that process's block, `reconciler` or `credentialManager`, and applies to that
Deployment only. A setting you want on both is written in both blocks.

| Parameter                                          | Description                                                                                  | Default                                                  |
|----------------------------------------------------|----------------------------------------------------------------------------------------------|----------------------------------------------------------|
| `image.repository`                                 | Image both processes run                                                                     | `gremlin/gremlin-operator`                               |
| `image.tag`                                        | Image tag                                                                                    | `""` (the chart `appVersion`)                            |
| `image.pullPolicy`                                 | Container pull policy for both processes                                                     | `IfNotPresent`                                           |
| `imagePullSecrets`                                 | Pull secrets for a private registry, added to both Deployments                               | `[]`                                                     |
| `nameOverride`                                     | Replaces the chart name in the `app.kubernetes.io/name` label and the object name prefix     | `""`                                                     |
| `fullnameOverride`                                 | Replaces the object name prefix. A DNS-1123 label of at most 28 characters                   | `""` (`gremlin-operator`)                                |
| `installNamespace.name`                            | Namespace the operator deploys agents into. A new namespace, not a system namespace. [See below](#namespaces-and-uninstall) | `gremlin`                                                |
| `installNamespace.create`                          | Create the install namespace and keep it on uninstall. [See below](#namespaces-and-uninstall) | `true`                                                  |
| `gremlinSystemNamespace.create`                    | Create `gremlin-system` and keep it on uninstall. [See below](#namespaces-and-uninstall)     | `true`                                                   |
| `credentialNamespaces`                             | Namespaces the credential manager may read. [See below](#credential-namespaces)             | `[]` (every namespace)                                   |
| `reconciler.replicas`                              | Reconciler replicas                                                                          | `1`                                                      |
| `reconciler.logLevel`                              | `debug`, `info`, `error`, `panic` or a positive integer                                      | `""` (no flag)                                           |
| `reconciler.resyncInterval`                        | Go duration such as `30s` or `1h30m`                                                         | `""` (the operator's `10m`)                              |
| `reconciler.serviceAccount.create`                 | Create the reconciler ServiceAccount                                                         | `true`                                                   |
| `reconciler.serviceAccount.annotations`            | Annotations for the reconciler ServiceAccount                                                | `{}`                                                     |
| `reconciler.resources`                             | Requests and limits for the reconciler container                                             | `10m`/`64Mi` requests, `500m`/`128Mi` limits             |
| `reconciler.nodeSelector`                          | Map of node labels for pod assignment                                                        | `{}`                                                     |
| `reconciler.tolerations`                           | List of node taints to tolerate                                                              | `[]`                                                     |
| `reconciler.affinity`                              | Map of node and pod affinities                                                               | `{}`                                                     |
| `reconciler.priorityClassName`                     | Priority class of the pod                                                                    | `""`                                                     |
| `reconciler.podAnnotations`                        | Pod annotations, merged over `kubectl.kubernetes.io/default-container`                       | `{}`                                                     |
| `reconciler.podSecurityContext`                    | Pod-level security context                                                                   | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`   |
| `reconciler.securityContext`                       | Container security context                                                                   | `allowPrivilegeEscalation: false`, drop `ALL`            |
| `reconciler.extraEnv`                              | Environment variables, rendered after the chart's own. [See below](#environment-variables)   | `[]`                                                     |
| `credentialManager.replicas`                       | Credential manager replicas                                                                  | `1`                                                      |
| `credentialManager.logLevel`                       | `debug`, `info`, `error`, `panic` or a positive integer                                      | `""` (no flag)                                           |
| `credentialManager.resyncInterval`                 | Go duration such as `30s` or `1h30m`                                                         | `""` (the operator's `10m`)                              |
| `credentialManager.serviceAccount.create`          | Create the credential manager ServiceAccount                                                 | `true`                                                   |
| `credentialManager.serviceAccount.annotations`     | Annotations for the credential manager ServiceAccount                                        | `{}`                                                     |
| `credentialManager.resources`                      | Requests and limits for the credential manager container                                     | `10m`/`64Mi` requests, `500m`/`512Mi` limits             |
| `credentialManager.nodeSelector`                   | Map of node labels for pod assignment                                                        | `{}`                                                     |
| `credentialManager.tolerations`                    | List of node taints to tolerate                                                              | `[]`                                                     |
| `credentialManager.affinity`                       | Map of node and pod affinities                                                               | `{}`                                                     |
| `credentialManager.priorityClassName`              | Priority class of the pod                                                                    | `""`                                                     |
| `credentialManager.podAnnotations`                 | Pod annotations, merged over `kubectl.kubernetes.io/default-container`                       | `{}`                                                     |
| `credentialManager.podSecurityContext`             | Pod-level security context                                                                   | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`   |
| `credentialManager.securityContext`                | Container security context                                                                   | `allowPrivilegeEscalation: false`, drop `ALL`            |
| `credentialManager.extraEnv`                       | Environment variables, rendered after the chart's own. [See below](#environment-variables)   | `[]`                                                     |
| `agent.nodeRead.enabled`                           | Let the agent read its node. [See below](#agent-node-read)                                   | `true`                                                   |
| `openshift.enabled`                                | Render the OpenShift objects. [See below](#openshift)                                        | `false`                                                  |

Specify each parameter using the `--set[-file] key=value[,key=value]` argument to `helm install`, or a values file.

The credential manager always runs with `--zap-devel=false`, and the chart has no value for extra arguments. The chart
offers no volumes, volume mounts or init containers either: the operator's Deployments own no volumes and need none.

## Environment variables

Each process has its own `extraEnv`. It renders after the chart's `GOMEMLIMIT` and `POD_NAMESPACE`, and Kubernetes uses
the last entry when a name appears twice, so an entry here overrides a chart-set variable for that process only.

`GOMEMLIMIT` is 100MiB for the reconciler and 400MiB for the credential manager, under memory limits of 128Mi and 512Mi.
If you override it, keep it below that process's memory limit. Overriding `POD_NAMESPACE` turns off the operator's check
that the install namespace differs from its own namespace.

## Credential namespaces

By default the credential manager reads Secrets in the whole cluster and works in `gremlin-system`. Setting
`credentialNamespaces` restricts it. The cluster-wide Secret binding is not rendered, each listed namespace other than
`gremlin-system` gets a read-only Role and RoleBinding for the credential manager, and the credential manager is told to
watch exactly the listed namespaces, in the order given. `gremlin-system` keeps its Role and is watched only when listed.

The list must include `installNamespace.name`. The chart does not create the listed namespaces, so create them before
you install. A listed namespace should hold only team-certificate Secrets, because the Role covers every Secret in it.
The release namespace may not be listed, because Helm stores its release Secrets there, and neither may `default` or a
`kube-` or `openshift-` namespace.

## Namespaces and uninstall

With default values the chart creates the install namespace and `gremlin-system`, and marks both to be kept when you run
`helm uninstall`. Uninstall removes every other object of the release, including the ServiceAccounts, Roles and
RoleBindings inside those namespaces and all cluster-scoped bindings. It leaves both namespaces and every Secret you put
in them. Never delete the kept namespaces: they hold credentials. A kept namespace still carries the release's ownership
annotations, so installing again with the same release name and namespace adopts it.

To reinstall under another release name, Helm refuses the kept namespaces because another release owns them. Set
`installNamespace.create` and `gremlinSystemNamespace.create` to `false` for the reinstall instead of deleting anything.
Setting one to `false` on a later upgrade leaves the existing namespace in place.

Choose a new install namespace with `installNamespace.name`. Do not point it at a namespace that already exists for
another purpose, such as the `gremlin` namespace of the `gremlin` chart: the credential manager gets write access to
Secrets in the install namespace and the reconciler can create workloads there. If you already run the `gremlin` chart in
`gremlin`, set `installNamespace.name` to another name, for example `gremlin-operator-agents`, rather than adopting it.

Renaming `installNamespace.name` on `helm upgrade` deletes the ServiceAccounts and grants in the old namespace, and the
old namespace is kept. DaemonSets and Chao Deployments the operator already created there keep running without them, so
delete your Agents before you rename it.

Helm never deletes the CRDs in `crds/`, so Agents and the DaemonSet and Chao Deployment they own keep running after
`helm uninstall`. Delete your Agents first.

## Agent node read

With `agent.nodeRead.enabled` set to `false`, the node-reader ClusterRole and its binding are not rendered and the
reconciler is passed `--agent-node-read=false`, so agents run with `GREMLIN_PUSH_POD_CIDR_TAGS` and
`GREMLIN_PUSH_ZONE_CIDR_TAGS` set to `false`. The value must be a boolean: the string `"false"` is rejected.

The flag exists only in newer operator releases. An operator that does not know `--agent-node-read` exits at start, so
the reconciler crash-loops. At the time of writing the operator version this chart was built against does not accept it,
so leave the value at `true` until the operator release you deploy supports it.

## OpenShift

With `openshift.enabled` set to `true` the chart renders the SecurityContextConstraints (SCC) `gremlin`, a Role and
RoleBinding named `<prefix>-agent-scc` that let the `gremlin-agent` ServiceAccount use it, and the
`pod-security.kubernetes.io/enforce: privileged` label on the install namespace.

The chart sets the label only on a namespace it creates. When `installNamespace.create` is `false`, add the label to the
existing install namespace yourself, with `kubectl label namespace <name> pod-security.kubernetes.io/enforce=privileged`,
or Pod Security refuses the agent pods. The reconciler reports refused pods as `PodsRejected` on the Agent.

The operator's SCC is named `gremlin`, the same name as the SCC the `gremlin` chart creates when
`gremlin.podSecurity.securityContextConstraints.create` is `true`. The two charts clash: with those settings on in both,
Helm refuses whichever chart you install second, because the SCC already exists. Do not turn both on at once.

`openshift.enabled` also needs an operator release that has the OpenShift support. Check the release you deploy before you
turn it on.

## Trust boundaries

These are the operator's own warnings, and they hold for a Helm install too.

* Whoever can create workloads, exec into pods or mint tokens in the release namespace holds every Secret in the cluster,
  because the credential manager's ServiceAccount lives there and reads them. Give that namespace to people you trust
  with every Secret. With `credentialNamespaces` set, the same applies to the listed namespaces only.
* The install namespace must hold no ServiceAccount more privileged than `gremlin-agent`. The credential manager can
  create and read Secrets there, which includes ServiceAccount token Secrets.
* Setting a `create` value to `false` adopts an existing namespace or ServiceAccount. Its existing admins and any tokens
  already minted for it keep working with the rights this chart grants.
* The `agent-editor` and `agent-admin` ClusterRoles that the chart ships are node-root and credential grants. Bind them
  only to cluster admins.
* Permission to create `teamcredentials` lets a principal probe which Secrets exist in its own namespace. Grant it with
  that in mind.

## Webhooks

Webhooks are not supported in this chart version. `values.yaml` holds a commented placeholder where their settings will
go.

## Upgrading CRDs

Helm installs the CRDs in `crds/` once and never upgrades or deletes them. When a new chart version changes a CRD,
apply it yourself before you run `helm upgrade`, for example with `kubectl apply -f gremlin-operator/crds/` from the
chart's source.
