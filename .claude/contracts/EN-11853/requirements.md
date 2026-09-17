# Requirements — Expose standard Helm chart configuration options on the Gremlin agent chart

- **Slug:** EN-11853
- **Ticket:** EN-11853
- **Elicited:** 2026-09-17
- **Gate 1:** ASSENTED by Danny Seymour on 2026-09-17 (sha256 68b77e513f54ee0c6fd4456c22f0e17de9b7ea8c5c323980a8c9de236c8c807f)

**Post-assent revisions**

- 2026-09-17 — Dropped B9 (reserved-name collision check retrofitted onto `extraEnv`); pod-level `securityContext` renumbered from B10 to B9 — during design, the architect found `extraEnv` renders last in both containers' `env:` lists, so a collision there is Kubernetes' last-wins override, a real working use case (e.g. overriding `GREMLIN_SERVICE_URL`/`https_proxy`), not a bug; retrofitting a hard failure would break existing installs on upgrade with no opt-in, conflicting with the "no diff on upgrade until opted in" constraint. Presented to the user as a genuine design fork with three options (fail unconditionally, add an opt-out escape hatch, drop the retrofit); user chose to drop it. Re-assented by Danny Seymour on 2026-09-17.

## Problem

The `gremlin` chart doesn't expose a number of configuration options that are standard for Helm
charts — probes, `initContainers`, `extraVolumes`/`extraVolumeMounts`, `lifecycle` hooks,
`envFrom`, `terminationGracePeriodSeconds`, `dnsConfig`, `hostAliases`, and pod-level
`securityContext`. Because these aren't surfaced as values, customers and Gremlin support have no
supported way to apply common workarounds when an issue comes up — they have to hand-patch the
rendered DaemonSet/Deployment with `kubectl patch`, which is fragile, undocumented, and gets
silently reverted by any GitOps tool that enforces drift correction (Flux, Argo CD). The concrete
trigger was a Bottlerocket/EKS Auto Mode race condition (EN-11846) whose only known workaround —
a `startupProbe` — could not be applied through Helm values.

## Actor and surface

- **Actor:** a Gremlin support engineer, SRE, or customer who applies the `gremlin` Helm chart
  (directly via `helm install`/`upgrade`, or via a GitOps controller reconciling a values file
  from git).
- **Surface:** the rendered/applied Kubernetes manifest — inspectable via `helm template`,
  `kubectl get daemonset/deployment -o yaml`, or `kubectl describe pod` — and, for invalid input,
  the `helm template`/`helm install` error output.

## Value naming convention

Values that apply only to the gremlin DaemonSet go at the **root** of `values.yaml`
(`<field>`), matching the chart's existing root-level `nodeSelector`/`tolerations`/`affinity`
(which are consumed only by the DaemonSet — chao has its own separate `chao.nodeSelector`/
`chao.tolerations`/`chao.affinity`). Values that apply only to chao go under `chao.<field>`. This
was an explicit correction from the user against this document's first draft, which had proposed
`gremlin.<field>` for DaemonSet-only values.

## Behaviors

### B1 — Probes (liveness/readiness/startup)

- **Given:** a value is set for root `livenessProbe`, `readinessProbe`, `startupProbe`, or
  `chao.livenessProbe`, `chao.readinessProbe`, `chao.startupProbe` (each a literal Kubernetes
  `Probe` object)
- **When:** the chart is templated/installed
- **Then:** the corresponding container in the rendered DaemonSet or Deployment carries that
  exact `Probe` under the matching field (`livenessProbe`/`readinessProbe`/`startupProbe`)
- **Today:** no probe fields exist anywhere in the rendered manifest for either workload; there is
  no value to set
- **Rejects:** not applicable — probes pass through as native objects; a malformed `Probe` is
  rejected by the Kubernetes API at apply time, not by the chart
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

### B2 — User-supplied `initContainers`

- **Given:** a value is set for root `initContainers` or `chao.initContainers` (a literal list of
  Kubernetes `Container` objects)
- **When:** the chart is templated/installed
- **Then:** each listed container is appended to the rendered `initContainers` list, **after**
  any chart-managed init container (currently only `seccomp-init`, rendered when
  `gremlin.podSecurity.seccomp.enabled` with the `localhost/gremlin` profile)
- **Today:** `chao` has no `initContainers` support at all; `gremlin` only ever renders the
  hardcoded `seccomp-init` container, with no hook for user-supplied ones
- **Rejects:**
  - **Given:** a user-supplied `initContainers` entry whose `name` is `seccomp-init`, `gremlin`,
    or `chao`
  - **Then:** the template render fails with a message naming the colliding container name
- **Timing:** not applicable
- **Modifies existing behavior:** no, new (ordering relative to `seccomp-init` is a
  strong-default, not a guarantee — see Constraints)

### B3 — `extraVolumes` / `extraVolumeMounts`

- **Given:** values are set for root `extraVolumes`/`extraVolumeMounts` or
  `chao.extraVolumes`/`chao.extraVolumeMounts` (literal lists of Kubernetes `Volume` and
  `VolumeMount` objects)
- **When:** the chart is templated/installed
- **Then:** each listed volume/mount is appended to the rendered pod's `volumes` and the target
  container's `volumeMounts`
- **Today:** all volumes and mounts on both workloads are entirely chart-computed; there is no
  generic extension point
- **Rejects:**
  - **Given:** a user-supplied volume or volume mount whose `name` matches a name the chart
    already manages (see the reserved list in the repo's `CLAUDE.md`, e.g. `gremlin-state`,
    `cgroup-root`, `seccomp-root`, `gremlin-cert`, `ssl-cert-file`, ...)
  - **Then:** the template render fails with a message naming the colliding volume name
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

### B4 — `lifecycle` hooks

- **Given:** a value is set for root `lifecycle` or `chao.lifecycle` (a literal Kubernetes
  `Lifecycle` object, i.e. `preStop`/`postStart`)
- **When:** the chart is templated/installed
- **Then:** the corresponding container carries that `Lifecycle` object
- **Today:** neither workload renders a `lifecycle` field at all
- **Rejects:** not applicable — passes through natively; malformed input is rejected by the
  Kubernetes API
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

### B5 — `envFrom`

- **Given:** a value is set for root `envFrom` or `chao.envFrom` (a literal list of Kubernetes
  `EnvFromSource` objects — `configMapRef`/`secretRef`)
- **When:** the chart is templated/installed
- **Then:** each listed source is appended to the corresponding container's `envFrom`
- **Today:** neither workload renders an `envFrom` field; only the hand-maintained `extraEnv`
  list exists for literal env vars
- **Rejects:** not applicable — `envFrom` references an existing ConfigMap/Secret by name rather
  than defining a new one, and the chart cannot see that object's keys at render time, so no
  chart-side collision check applies (see Constraints)
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

### B6 — `terminationGracePeriodSeconds`

- **Given:** a value is set for root `terminationGracePeriodSeconds` or
  `chao.terminationGracePeriodSeconds` (a literal integer)
- **When:** the chart is templated/installed
- **Then:** the rendered pod spec carries that `terminationGracePeriodSeconds`
- **Today:** neither workload exposes this field; the Kubernetes default (30s) applies
  unconditionally
- **Rejects:** not applicable — passes through natively
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

### B7 — `dnsConfig`

- **Given:** a value is set for root `dnsConfig` or `chao.dnsConfig` (a literal Kubernetes
  `PodDNSConfig` object)
- **When:** the chart is templated/installed
- **Then:** the rendered pod spec carries that `dnsConfig`
- **Today:** only `gremlin.dnsPolicy` is exposed (gremlin only); there is no way to set custom
  nameservers/search domains on either workload
- **Rejects:** not applicable — passes through natively
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

### B8 — `hostAliases`

- **Given:** a value is set for root `hostAliases` or `chao.hostAliases` (a literal list of
  Kubernetes `HostAlias` objects)
- **When:** the chart is templated/installed
- **Then:** the rendered pod spec carries that `hostAliases` list
- **Today:** neither workload exposes this field
- **Rejects:** not applicable — passes through natively
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

### B9 — Pod-level `securityContext`

- **Given:** a value is set for root `podSecurityContext` or `chao.podSecurityContext` (a literal
  Kubernetes pod-level `SecurityContext` object — `runAsNonRoot`/`runAsUser`/`fsGroup`/etc.)
- **When:** the chart is templated/installed
- **Then:** the rendered pod spec carries that `securityContext` at the pod level, alongside the
  existing container-level `securityContext` (unaffected)
- **Today:** neither workload exposes pod-level `securityContext`; `chao` has only a hardcoded
  container-level `readOnlyRootFilesystem: true`, and `gremlin` only exposes container-level
  fields via `gremlin.podSecurity.*`
- **Rejects:** not applicable — passes through natively
- **Timing:** not applicable
- **Modifies existing behavior:** no, new

## Out of scope

- `chao.replicas` — hardcoded to `1`; a correctness constraint (chao isn't built for multiple
  replicas), not a gap.
- `serviceAccountName` overrides on either workload — already worked around via IRSA annotations
  on the existing ServiceAccount.
- Refactoring `chao-deployment.yaml` to share `_daemonset.tpl`'s named-template pattern. The two
  templates are structurally different today (see `mem:conventions`); bringing them in line is a
  separate, unrequested refactor.
- Any default/example probe, lifecycle hook, etc. shipped by the chart itself — this ticket adds
  the mechanism only; solving EN-11846 itself (choosing and shipping a specific `startupProbe`)
  is separate.
- Retrofitting a reserved-name collision check onto the pre-existing `extraEnv` value. `extraEnv`
  renders last in both containers' `env:` lists, so a collision there is Kubernetes' last-wins
  override — a real, working use case, not a bug. See Post-assent revisions.

## Constraints

| Constraint | Rationale | Firmness | Needs clause? |
|---|---|---|---|
| Every new value defaults to a no-op (`{}`, `[]`, or unset) and, when unset, produces byte-identical rendered output to today | Backward compatibility — existing installs must not see any diff on upgrade until they opt in | binding | yes |
| DaemonSet-only values live at the root of `values.yaml`; chao-only values live under `chao.*` | Matches the chart's existing split (`nodeSelector`/`tolerations`/`affinity` at root, `chao.nodeSelector`/etc. separately) — user's explicit correction | binding | no (shapes value paths in every behavior above) |
| New values pass through native Kubernetes API shapes with no chart-side schema validation beyond the reserved-name collision check | Matches the chart's existing convention (`extraEnv`, GPU vendor `volumes`/`volumeMounts` blocks); avoids the chart re-implementing Kubernetes API validation | binding | no (shapes the `then`s above, not a separate clause) |
| `extraVolumes`, `extraVolumeMounts`, and `initContainers` (new values only) fail the template render on a name collision with a chart-reserved name, per the reserved list now recorded in the repo's `CLAUDE.md` | User confirmed: silent collision (K8s API rejection or shadowed chart resource) is worse than a clear failure naming the conflict | binding | yes (B2, B3 `Rejects`) |
| `envFrom` and `extraEnv` are exempt from the reserved-name collision check | `envFrom` references an existing object rather than defining one, so there's nothing to statically check; `extraEnv` renders last and a collision there is a working last-wins override, not a bug — retrofitting a failure was considered and rejected (design fork, see Post-assent revisions) | binding | no (reflected in B5's `Rejects: not applicable`; B9 retrofit dropped) |
| User-supplied `initContainers` are appended **after** any chart-managed init container (`seccomp-init`) | User's stated default; ordering may need to change later if a workaround requires running before `seccomp-init` | strong-default | yes (B2 `then`) |
| Pod-level `securityContext` is added to **both** `gremlin` and `chao`, not chao-only as the ticket's audit literally listed | User confirmed symmetry is wanted | binding | yes (B9 covers both) |
| Both workloads get all nine areas (except where Out of scope excludes something) | Ticket's explicit ask | binding | yes (B1-B9) |

## Affected consumers

- Existing chart users and GitOps controllers (Flux, Argo CD) reconciling from a values file —
  must see no diff on upgrade when new values are left unset.
- Gremlin support workflows that currently document `kubectl patch` workarounds — expected to
  migrate to the new values once available (not this ticket's concern to update, but the reason
  the ticket exists).

## Production signal

This is a chart-rendering feature with no live telemetry surface of its own, so the practical
signal is: for each of B1-B9, a `helm-unittest` spec renders the chart with a representative,
non-trivial value set for that area (on both `gremlin` and `chao` where applicable) and asserts
the corresponding field appears correctly in the rendered manifest — plus one spec per default
(unset) case asserting the rendered manifest is unchanged from today. The `initContainers` and
`extraVolumes`/`extraVolumeMounts` rejects (B2, B3) each get a spec asserting the render fails on
a reserved-name collision. Passing this suite in CI is the signal that these values behave as
specified; the longer-term signal that the underlying problem (drift-hostile workarounds) is
solved is qualitative — support engineers no longer need `kubectl patch` for cases the new values
cover, starting with the EN-11846 `startupProbe` workaround.

## Assumptions

| # | Assumption | Confirmed? |
|---|---|---|
| A1 | DaemonSet-only values are named at the root of `values.yaml` (`<field>`); chao-only values under `chao.<field>` | corrected — see Value naming convention |
| A2 | No chart version bump or `values.yaml` documentation format changes beyond following the existing `# <dotted.path> -` comment convention are needed as part of this requirements phase (left to implementation/task_completion checklist) | yes |

## Open questions

### Blocking — Gate 1 cannot pass while any remain

(none)

### Carried — recorded as risk, does not block

- The `initContainers` append-after-`seccomp-init` ordering is a strong default the user
  explicitly flagged as possibly needing revisiting; if a future workaround needs a user
  `initContainer` to run *before* `seccomp-init`, this will need a follow-up amendment.
