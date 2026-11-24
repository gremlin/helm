# Gremlin Operator Helm Chart

This chart installs the Gremlin Kubernetes Operator: the reconciler and the credential manager, each as its own
Deployment, with the Gremlin CRDs and the RBAC they need. The operator then deploys and manages Gremlin agents for each
`Agent` resource you create.

## Prerequisites

* Helm 3
* Adding the Gremlin helm repo. `helm repo add gremlin https://helm.gremlin.com/ && helm repo update`
* Permission to create cluster-scoped resources: the CRDs, ClusterRoles and ClusterRoleBindings.
* Only one operator install per cluster works: the CRDs, ClusterRoles and the names `gremlin-agent` and `gremlin-chao`
  are cluster-wide or fixed by the operator.
* No `gremlin-system` namespace left from an older operator layout. See [Install](#install).

## Install

```shell
helm install gremlin-operator gremlin/gremlin-operator \
    --namespace gremlin-system --create-namespace
```

The operator runs in the release namespace, `gremlin-system` above, where both Deployments run. Agents and Chao run in
the install namespace `gremlin`, which the chart creates. Team credentials live in the install namespace by default, or
in any other namespace the credential manager can read, but never in the release namespace: the operator's own Secrets
live there, and anyone who can create workloads there holds the credential manager's identity. The chart refuses `default`, `openshift` and any `kube-` or `openshift-`
namespace as the release namespace. See [Trust boundaries](#trust-boundaries).

Clean a `gremlin-system` namespace that an older operator layout left behind before you install. `--create-namespace`
neither adopts nor cleans an existing namespace, and the older layout kept the credential manager's Secret rights there,
in a Role and RoleBinding that name a different operator namespace. Anyone who can claim that namespace would hold Secret
write in `gremlin-system`. On a real install the chart refuses to continue while either object exists. Delete those grants in place: the RoleBindings and workloads in it that are not the
operator's, including `gremlin-operator-credential-manager-rolebinding` and `gremlin-operator-credential-manager-role`.
Do not delete the namespace while team credential Secrets or `TeamCredential` resources are in it, because deleting it
deletes them and installing the chart does not restore them. If you must delete it, back them up first and re-create
them in the install namespace afterwards.

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
| `nameOverride`                                     | Replaces the chart name in the `app.kubernetes.io/name` label and the object name prefix, at most 28 characters when `fullnameOverride` is empty | `""`                                                     |
| `fullnameOverride`                                 | Replaces the object name prefix. A DNS-1123 label of at most 28 characters                   | `""` (`gremlin-operator`)                                |
| `installNamespace.name`                            | Namespace the operator deploys agents into. A new namespace, not a system namespace. [See below](#namespaces-and-uninstall) | `gremlin`                                                |
| `installNamespace.create`                          | Create the install namespace, labelled privileged for Pod Security, and keep it on uninstall. [See below](#namespaces-and-uninstall) | `true`                                                  |
| `reconciler.replicas`                              | Reconciler replicas. [See below](#high-availability)                                         | `3`                                                      |
| `reconciler.logLevel`                              | `debug`, `info`, `error`, `panic` or a positive integer up to 127                           | `""` (no flag)                                           |
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
| `credentialManager.replicas`                       | Credential manager replicas. [See below](#high-availability)                                 | `3`                                                      |
| `credentialManager.logLevel`                       | `debug`, `info`, `error`, `panic` or a positive integer up to 127                           | `""` (no flag)                                           |
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

## High availability

Each process runs three replicas by default. Each process elects a leader, so one replica acts at a time and the other
two stand by; the operator's own install runs one replica, and this chart does not. The chart adds no PodDisruptionBudget,
pod anti-affinity or topology spread constraints, so the replicas of a process can land on the same node. To spread them,
set `affinity` in the process's block, `reconciler` or `credentialManager`. Three replicas of each process need room for
six small pods, so on a single-node or kind cluster you may want to set both `replicas` to `1`. Every credential manager
replica, standby included, holds the ServiceAccount token that reads every Secret in the cluster; use
`credentialManager.nodeSelector` or `affinity` to keep them on nodes you trust.

## Environment variables

Each process has its own `extraEnv`. It renders after the chart's `GOMEMLIMIT` and `POD_NAMESPACE`, and Kubernetes uses
the last entry when a name appears twice, so an entry here overrides a chart-set variable for that process only.

`GOMEMLIMIT` is 100MiB for the reconciler and 400MiB for the credential manager, under memory limits of 128Mi and 512Mi.
If you override it, keep it below that process's memory limit. Overriding `POD_NAMESPACE` turns off the operator's check
that the install namespace differs from its own namespace.

## Namespaces and uninstall

With default values the chart creates the install namespace and marks it to be kept when you run `helm uninstall`. The
release namespace, `gremlin-system` in the install command, is made by `--create-namespace` and is not part of the
release, so Helm leaves it too. Uninstall removes every other object of the release, including the ServiceAccounts,
Roles and RoleBindings inside the namespaces and all cluster-scoped bindings. It leaves the install namespace and every
Secret you put in it. Never delete the kept install namespace: it holds credentials. It also stays labelled privileged, so once no Agent runs
there, remove the label with `kubectl label namespace <name> pod-security.kubernetes.io/enforce-` or restrict who can
create pods in it. It still carries the release's
ownership annotations, so installing again with the same release name and namespace adopts it.

To reinstall under another release name, Helm refuses the kept install namespace because another release owns it. Set
`installNamespace.create` to `false` for the reinstall instead of deleting anything. Setting it to `false` on a later
upgrade leaves the existing namespace in place.

The chart always labels an install namespace it creates `pod-security.kubernetes.io/enforce: privileged`, on every
cluster, because the agent pods run on the host's network and PID namespaces and Pod Security would refuse them
otherwise. It does not label the release namespace.

When `installNamespace.create` is `false`, the chart does not create or label the install namespace. On any cluster whose
Pod Security default blocks privileged pods, not only OpenShift, add the label to the existing namespace yourself, with
`kubectl label namespace <name> pod-security.kubernetes.io/enforce=privileged`, or Pod Security refuses the agent pods. The
reconciler reports refused pods as `PodsRejected` on the Agent.

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

The flag exists only in operator releases that include the node-read switch. An older operator that does not know
`--agent-node-read` exits at start, so the reconciler crash-loops. Check that the release you deploy has it before you
turn the node read off.

## OpenShift

With `openshift.enabled` set to `true` the chart renders the SecurityContextConstraints (SCC) `gremlin`, and a Role and
RoleBinding named `<prefix>-agent-scc` that let the `gremlin-agent` ServiceAccount use it.

The operator's SCC is named `gremlin`, the same name as the SCC the `gremlin` chart creates when
`gremlin.podSecurity.securityContextConstraints.create` is `true`. The two charts clash: with those settings on in both,
Helm refuses whichever chart you install second, because the SCC already exists. Do not turn both on at once.

`openshift.enabled` also needs an operator release that has the OpenShift support. Check the release you deploy before you
turn it on.

## Trust boundaries

These are the operator's own warnings, and they hold for a Helm install too.

* Whoever can create workloads, exec into pods or mint tokens in the release namespace holds every Secret in the cluster,
  because the credential manager's ServiceAccount lives there and reads them. Give that namespace to people you trust
  with every Secret. The chart always binds that cluster-wide read; it offers no way to narrow it to listed namespaces.
* The install namespace must hold no ServiceAccount more privileged than `gremlin-agent` and `gremlin-chao`. The credential manager can
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

## Upgrading from an older operator layout

This applies to development, demo and CI clusters that ran the operator in a namespace other than `gremlin-system`, with
its Secret rights in a separate credential namespace. Remove that install and clean `gremlin-system` first, as
[Install](#install) describes; back up any team credentials that are in it before you remove anything. Then install the chart. Apply the Agent CRD before or together with the new image: a
CRD older than the credential manager makes its status write fail, so no credential is copied and the pods of an Agent
that names proxy credentials, a trust bundle or an identity are held.

The reconciler's NetworkPolicy admits metrics scrapers only from namespaces labelled `metrics=enabled`, and the older
layout shipped no such policy. Label the namespaces your scrapers run in before the upgrade:
`kubectl label namespace <namespace> metrics=enabled`.

## Upgrading CRDs

Helm installs the CRDs in `crds/` once and never upgrades or deletes them. When a new chart version changes a CRD,
apply it yourself before you run `helm upgrade`, for example with `kubectl apply -f gremlin-operator/crds/` from the
chart's source.
