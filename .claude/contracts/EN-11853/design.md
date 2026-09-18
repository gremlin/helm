# Design — EN-11853: Expose standard Helm chart configuration options

- **Slug:** EN-11853
- **Traces to:** `.claude/contracts/EN-11853/requirements.md` (Gate 1 assented 2026-09-17)
- **Authored:** 2026-09-17
- **Status:** complete. The one decision surfaced to the human during design (the `extraEnv`
  retrofit) has been resolved — dropped; see §9.

---

## 0. Summary

Twelve new values per workload (twenty-four total), all pure pass-through, plus a reserved-name
collision check on the two new name-defining values (`initContainers`, `extraVolumes`/
`extraVolumeMounts`). Three files change structurally (`_daemonset.tpl`, `chao-deployment.yaml`,
`_validation.tpl`), two change by one line each (`daemonset.yaml`, `CLAUDE.md`), and
`values.yaml` gains two documented blocks.

`gremlin.extraEnv` and `chao.extraEnv` are **not touched by this change** — see §9.

No refactor of `chao-deployment.yaml` toward `_daemonset.tpl`'s named-template shape (out of scope
per requirements).

### Files changed

| File | Change |
|---|---|
| `gremlin/values.yaml` | +12 root keys, +12 `chao.*` keys, all documented |
| `gremlin/templates/_daemonset.tpl` | pod-spec block, `initContainers` restructure, container-field block, two list appends |
| `gremlin/templates/chao-deployment.yaml` | pod-spec block, `initContainers`, container-field block, `volumeMounts:` gate fix + append, `volumes` append |
| `gremlin/templates/daemonset.yaml` | one `include` line |
| `gremlin/templates/_validation.tpl` | +6 named templates (reserved lists, generic collide, two per-workload entry points) |
| `CLAUDE.md` | reserved-list section: `extraEnv` moved from "covered" to "exempt" — *already applied 2026-09-17* (§9); still to add: the GPU-vendor "not covered" note (§5.5) |
| `gremlin/tests/` | new spec files (§8) |

---

## 1. The dict-context hazard (read this first)

`_daemonset.tpl` is invoked as `include "gremlin.daemonset" (dict "root" $ ...)`. Inside the
`define`, `.` **is the dict, not the chart root**. Every value access must be
`$root.Values.foo`. A bare `.Values.foo` inside `_daemonset.tpl` resolves to nothing —
silently, with no error — so a snippet copy-pasted from `chao-deployment.yaml` will render an
empty result and every test for it will fail with "field absent" rather than a template error.

`chao-deployment.yaml` is rendered directly by Helm, so it uses `.Values.foo` throughout.

Every snippet in this document is written for its target file. Do not move one between files
without rewriting the accessor.

---

## 2. Value names and shapes (B1–B9)

DaemonSet-only values at the root; chao-only values under `chao.*`. Twelve names, identical on
both sides.

| Behavior | Root key (DaemonSet) | `chao.*` key | Default | K8s shape |
|---|---|---|---|---|
| B1 | `livenessProbe` | `chao.livenessProbe` | `{}` | `Probe` |
| B1 | `readinessProbe` | `chao.readinessProbe` | `{}` | `Probe` |
| B1 | `startupProbe` | `chao.startupProbe` | `{}` | `Probe` |
| B2 | `initContainers` | `chao.initContainers` | `[]` | `[]Container` |
| B3 | `extraVolumes` | `chao.extraVolumes` | `[]` | `[]Volume` |
| B3 | `extraVolumeMounts` | `chao.extraVolumeMounts` | `[]` | `[]VolumeMount` |
| B4 | `lifecycle` | `chao.lifecycle` | `{}` | `Lifecycle` |
| B5 | `envFrom` | `chao.envFrom` | `[]` | `[]EnvFromSource` |
| B6 | `terminationGracePeriodSeconds` | `chao.terminationGracePeriodSeconds` | *(null)* | integer |
| B7 | `dnsConfig` | `chao.dnsConfig` | `{}` | `PodDNSConfig` |
| B8 | `hostAliases` | `chao.hostAliases` | `[]` | `[]HostAlias` |
| B9 | `podSecurityContext` | `chao.podSecurityContext` | `{}` | `PodSecurityContext` |

`gremlin.extraEnv` and `chao.extraEnv` are untouched: not moved, not renamed, not validated. They
are named here only because B5's `envFrom` sits beside them in the rendered container and in
`values.yaml`. Note the asymmetry that leaves behind — the DaemonSet's env value lives at
`gremlin.extraEnv` while its new `envFrom` lives at the root. That predates this ticket and
moving it is not in scope.

### 2.1 Why these defaults

`{}` and `[]` are falsy in Go templates, so every field is emitted under `{{- with }}` and the
default render is byte-identical to today's. That is the binding backward-compatibility
constraint; it is satisfied structurally, not by a test.

`terminationGracePeriodSeconds` is the one scalar and the one exception. It defaults to a bare
key (null). It must **not** use `{{- with }}`: `0` is a legal Kubernetes value and is falsy, so
`with` would silently drop it. Guard it with `{{- if not (kindIs "invalid" <value>) }}` instead,
which is true for null and false for `0`. This is deliberate and applies to this field only —
do not generalize the idiom to the other eleven.

### 2.2 values.yaml placement and documentation

**Root block:** insert after `affinity: {}` (line 24), before `gremlin:` (line 26).

**Chao block:** insert after `chao.extraEnv` (line 529), before `chao.namespaces` (line 531) —
keeping `extraEnv`/`envFrom` adjacent.

Both blocks list the twelve keys in the table's order, so the two are diffable side by side.

Every key carries a `# <dotted.path> -` doc comment matching the file's existing convention
(`# gremlin.extraEnv -`, `# chao.priorityClassName -`). For root keys the dotted path is just
the key name (`# livenessProbe -`).

Each **root** doc comment must state the scope explicitly, because these names are generic enough
that a reader will otherwise assume they cover both workloads:

> `# livenessProbe -`
> `# A Kubernetes Probe for the Gremlin Agent container. Applies to the Gremlin DaemonSet only;`
> `# the Chao deployment has its own chao.livenessProbe. Passed through to the rendered manifest`
> `# as-is. Unset by default, which renders no probe.`

Each **chao** doc comment mirrors it, naming the Chao deployment.

Comments for `extraVolumes`, `extraVolumeMounts`, and `initContainers` must additionally say that
a name colliding with one the chart manages fails the install, and name a couple of examples.

---

## 3. `_daemonset.tpl` — exact placements

Anchors are current line numbers in `gremlin/templates/_daemonset.tpl` (299 lines).

### 3.1 Capture the seccomp-init condition (new, near line 23)

The seccomp-init guard is needed in two places after the restructure. Hoist it into a variable
alongside the existing `$cdiDevice` capture, immediately after line 23:

```
{{- $seccompInit := and $root.Values.gremlin.podSecurity.seccomp.enabled (eq "localhost/gremlin" $root.Values.gremlin.podSecurity.seccomp.profile) -}}
```

The expression is copied verbatim from the current line 107 condition. No behavior change.

### 3.2 Pod-spec fields — B6, B7, B8, B9 (insert between lines 102 and 103)

After `hostNetwork: {{ $root.Values.gremlin.hostNetwork }}` (102), before the `imagePullSecrets`
conditional (103). Pod-spec keys sit at indent 6; their values at indent 8, matching the
neighboring `affinity`/`nodeSelector`/`tolerations` blocks (lines 91–99).

```
      {{- if not (kindIs "invalid" $root.Values.terminationGracePeriodSeconds) }}
      terminationGracePeriodSeconds: {{ $root.Values.terminationGracePeriodSeconds }}
      {{- end }}
      {{- with $root.Values.dnsConfig }}
      dnsConfig: {{ toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.hostAliases }}
      hostAliases: {{ toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.podSecurityContext }}
      securityContext: {{ toYaml . | nindent 8 }}
      {{- end }}
```

Note B9's value is named `podSecurityContext` but renders as the pod spec's `securityContext`
key. The container-level `securityContext` at lines 130–138 is untouched.

### 3.3 `initContainers` restructure — B2 (replaces lines 107–121)

This is the one structural change in the file. Today `initContainers:` is emitted *only* when
seccomp-init applies; B2 requires user containers to render whether or not it does, and to come
after it when both are present.

The fix is to widen the outer guard to an `or`, and give the seccomp-init entry its own inner
conditional. The seccomp-init entry's body (current lines 109–120) is moved **verbatim, at its
existing indentation** — this is what makes the default render byte-identical.

```
      {{- if or $seccompInit $root.Values.initContainers }}
      initContainers:
        {{- if $seccompInit }}
        - name: seccomp-init
          ... existing lines 110-120, unchanged ...
        {{- end }}
        {{- with $root.Values.initContainers }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
```

Ordering follows from position: the chart-managed entry is emitted before the user's list.
This satisfies B2's "after any chart-managed init container" and is the strong-default the
requirements flagged as revisitable (carried risk); nothing in this design makes reversing it
harder than moving the two blocks.

An empty list is falsy, so `or` is false and `with` is skipped — the unset case renders exactly
as today.

### 3.4 Container fields — B1, B4, B5 (insert between lines 209 and 210)

After the `gremlin.extraEnv` block closes (209), before `volumeMounts:` (210). Container keys sit
at indent 8; their values at indent 10.

```
        {{- with $root.Values.envFrom }}
        envFrom: {{ toYaml . | nindent 10 }}
        {{- end }}
        {{- with $root.Values.livenessProbe }}
        livenessProbe: {{ toYaml . | nindent 10 }}
        {{- end }}
        {{- with $root.Values.readinessProbe }}
        readinessProbe: {{ toYaml . | nindent 10 }}
        {{- end }}
        {{- with $root.Values.startupProbe }}
        startupProbe: {{ toYaml . | nindent 10 }}
        {{- end }}
        {{- with $root.Values.lifecycle }}
        lifecycle: {{ toYaml . | nindent 10 }}
        {{- end }}
```

The `envFrom, livenessProbe, readinessProbe, startupProbe, lifecycle` order is fixed, and
`chao-deployment.yaml` uses the same block in the same order (§4.4) so the two templates stay
diffable.

### 3.5 `extraVolumeMounts` — B3 (insert between lines 247 and 248)

Append at the end of the container's `volumeMounts:` list — after the `gremlin-opencl-icd`
conditional closes (247), before the pod-level `volumes:` key (248). Mount entries sit at
indent 10.

```
          {{- with $root.Values.extraVolumeMounts }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
```

This lands after the existing `$gpu.volumeMounts` append (239–241), so chart-managed mounts
always precede user ones — matching how `gremlin.extraEnv` already sits last in `env:`.

### 3.6 `extraVolumes` — B3 (insert between lines 295 and 296)

Append at the end of the pod's `volumes:` list — after the `gremlin-opencl-icd` configMap entry
closes (295), before the `priorityClassName` conditional (296). Volume entries sit at indent 8.

```
        {{- with $root.Values.extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
```

---

## 4. `chao-deployment.yaml` — exact placements

Anchors are current line numbers in `gremlin/templates/chao-deployment.yaml` (180 lines). All
accessors are `.Values.foo` (see §1). Note chao's indentation differs from the DaemonSet's:
container list entries sit at indent 8, container keys at 10, container values at 12, pod-level
volume entries at 6.

Everything below is inside the existing `{{ if .Values.chao.create }}` guard, so `chao.create:
false` renders nothing, as today.

### 4.1 Collision check (insert as line 3)

See §5.3.

### 4.2 Pod-spec fields + initContainers — B2, B6, B7, B8, B9 (insert between lines 55 and 56)

After the `imagePullSecrets` conditional closes (55), before `containers:` (56).

```
      {{- if not (kindIs "invalid" .Values.chao.terminationGracePeriodSeconds) }}
      terminationGracePeriodSeconds: {{ .Values.chao.terminationGracePeriodSeconds }}
      {{- end }}
      {{- with .Values.chao.dnsConfig }}
      dnsConfig: {{ toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.chao.hostAliases }}
      hostAliases: {{ toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.chao.podSecurityContext }}
      securityContext: {{ toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.chao.initContainers }}
      initContainers: {{ toYaml . | nindent 8 }}
      {{- end }}
```

chao has no chart-managed init container, so `initContainers:` is a plain `with`-guarded list
with no ordering to preserve. It is placed last in this block, immediately above `containers:`,
so init and main containers read in execution order.

### 4.3 Container fields — B1, B4, B5 (insert between lines 108 and 109)

After the `chao.extraEnv` block closes (108), before `args:` (109). Same field order as §3.4.

```
          {{- with .Values.chao.envFrom }}
          envFrom: {{ toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.chao.livenessProbe }}
          livenessProbe: {{ toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.chao.readinessProbe }}
          readinessProbe: {{ toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.chao.startupProbe }}
          startupProbe: {{ toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.chao.lifecycle }}
          lifecycle: {{ toYaml . | nindent 12 }}
          {{- end }}
```

### 4.4 `extraVolumeMounts` — B3: gate fix (line 148) + append (after line 163)

**This is the easy-to-miss one.** In chao, the `volumeMounts:` *key itself* is conditional:

```
{{- if (or ((eq (include "gremlin.secretType" .) "certificate")) .Values.ssl.certFile (include "chaoTlsIdentityVolumeMounts" .)) }}
          volumeMounts:
{{- end }}
```

With a secret-type (not certificate) auth config, no `ssl.certFile`, and no TLS identity, that
condition is false and the key is absent — so appending mounts alone would emit orphaned list
entries under `name: chao`, producing invalid YAML rather than a missing field.

**Fix:** extend the `or` with `.Values.chao.extraVolumeMounts` as a fourth term (line 148),
leaving the other three terms untouched:

```
{{- if (or ((eq (include "gremlin.secretType" .) "certificate")) .Values.ssl.certFile (include "chaoTlsIdentityVolumeMounts" .) .Values.chao.extraVolumeMounts) }}
```

**Rejected alternative:** always emitting `volumeMounts:` unconditionally. It would render a bare
`volumeMounts:` key with a null value whenever nothing applies, which changes today's default
output and breaks the byte-identical constraint. There is no third option; this is not a fork.

**Append:** after the `chaoTlsIdentityVolumeMounts` block closes (163), before `volumes:` (164).
Mount entries sit at indent 10.

```
{{- with .Values.chao.extraVolumeMounts }}
{{- toYaml . | nindent 10 }}
{{- end }}
```

### 4.5 `extraVolumes` — B3 (insert between lines 175 and 176)

chao's pod-level `volumes:` key is unconditional (line 164) — `gremlin-cert` always renders — so
there is no gating wrinkle here. Append after the `chaoTlsIdentityVolumes` block closes (175),
before the `priorityClassName` conditional (176). Volume entries sit at indent 6.

```
{{- with .Values.chao.extraVolumes }}
{{- toYaml . | nindent 6 }}
{{- end }}
```

---

## 5. Reserved-name collision checks — B2, B3

### 5.1 Pattern: direct named-template + `fail`, included at the top of the resource template

Recon's recommendation (b) is **accepted**. Rationale:

- The aggregate `gremlin.validateValues` pattern is reachable only through `NOTES.txt`, so
  `helm template -s templates/daemonset.yaml` — and any tooling that renders a single template —
  skips it entirely. A check that silently does not run is worse than no check.
- `CLAUDE.md` already specifies the shape: "a `_validation.tpl`-style `fail` check, **included at
  the top of the resource template**". (Its claim that the rule also covers `extraEnv` is
  superseded — see §9.)
- `chaoNamespacesValidate` is the existing precedent for exactly this, with an existing test
  idiom (`chao_deployment_namespaces_test.yaml` asserts `failedTemplate` against
  `chao-deployment.yaml` directly, not `NOTES.txt`).

The new templates live in `gremlin/templates/_validation.tpl` — that is where validation belongs —
but are **not** wired into `gremlin.validateValues`'s aggregate message list. Their names use a
`gremlin.validateReservedNames.*` / `gremlin.reservedNames.*` prefix precisely so the distinction
is visible: anything named `gremlin.validateValues.*` is an aggregate contributor that returns a
message string; these return nothing and call `fail` themselves.

### 5.2 Templates to define (all in `gremlin/templates/_validation.tpl`)

| Template | Context | Returns / does |
|---|---|---|
| `gremlin.reservedNames.volumes` | `.` (chart root) | space-separated reserved volume names |
| `gremlin.reservedNames.containers` | `.` | space-separated reserved container names |
| `gremlin.validateReservedNames.check` | `dict "entries" <list> "reserved" <list> "valuePath" <string> "kind" <string>` | calls `fail` on the first entry whose `.name` is in `reserved`; otherwise renders nothing |
| `gremlin.validateReservedNames.daemonset` | `.` | runs the three checks for the DaemonSet |
| `gremlin.validateReservedNames.chao` | `.` | runs the three checks for chao |

There is no `gremlin.reservedNames.env`. The env-var reserved list existed only for the dropped
`extraEnv` check (§9), and nothing else in this design references it — do not add it as dead code.
The env-var names stay documented in `CLAUDE.md` as a record of what the chart owns; they simply
have no check behind them.

The reserved-name templates emit a space-separated string; callers turn it into a list with
`splitList " " (include "gremlin.reservedNames.volumes" .)`. (Helm templates can only return
strings; this is the standard idiom.) Keeping the two lists in their own named templates means
there is exactly one place to edit when a new chart-managed name appears, which is what
`CLAUDE.md`'s maintenance rule assumes.

`gremlin.validateReservedNames.check` is the whole of the matching logic — complexity pushed into
the abstraction, six near-identical one-line call sites. An entry with no `name` field does not
match and is left to the Kubernetes API to reject.

### 5.3 What each entry point checks

`gremlin.validateReservedNames.daemonset`:

| Value path | Reserved list | `kind` word |
|---|---|---|
| `initContainers` | containers | `container` |
| `extraVolumes` | volumes | `volume` |
| `extraVolumeMounts` | volumes | `volume` |

`gremlin.validateReservedNames.chao`: the same three against `chao.initContainers`,
`chao.extraVolumes`, `chao.extraVolumeMounts`.

`extraVolumeMounts` is checked against the **volume** list, not a separate one: a mount's `name`
must refer to a volume, so reusing a chart-managed volume name in a mount is the same collision
seen from the other end.

`envFrom` and `extraEnv` are deliberately **not** checked — `envFrom` because it references an
existing object rather than defining one (B5), `extraEnv` per §9.

### 5.4 Include sites

**`gremlin/templates/daemonset.yaml`** — insert immediately after the header comment block closes
(`*/ -}}`, line 10), before `{{- $fullname := ... -}}` (line 11):

```
{{- include "gremlin.validateReservedNames.daemonset" . -}}
```

It goes in the dispatcher, not in `_daemonset.tpl`. `_daemonset.tpl` renders once per GPU vendor
plus a `-gpu-none` copy, so the same check would run up to N+1 times for identical input. The
dispatcher runs once regardless of fan-out, and the values being checked are fan-out-independent.

**`gremlin/templates/chao-deployment.yaml`** — insert as line 3, immediately after the existing
`{{- include "chaoNamespacesValidate" . -}}`:

```
{{- include "gremlin.validateReservedNames.chao" . -}}
```

This sits inside `{{ if .Values.chao.create }}`, matching `chaoNamespacesValidate`: when chao is
not created its values are inert and there is nothing to validate. That is the existing,
tested-for behavior (`chao_deployment_namespaces_test.yaml`'s last case).

### 5.5 Reserved lists (static, one set shared by both workloads)

Transcribed from `CLAUDE.md`:

- **Volumes:** `gremlin-state`, `gremlin-executions`, `gremlin-logs`, `cgroup-root`,
  `seccomp-root`, `seccomp-profile`, `gremlin-cert`, `ssl-cert-file`, `gremlin-tls-identity`,
  `chao-tls-identity`, `gremlin-opencl-icd`, `docker-sock`, `containerd-sock`, `crio-sock`,
  `kfd`, `dri`, `opencl-vendors`
- **Containers:** `seccomp-init`, `gremlin`, `chao`

`CLAUDE.md`'s third list — env var names — is **not** transcribed into a template. It has no
check behind it (§9) and remains documentation only.

**One shared list per kind, applied to both workloads.** The DaemonSet and chao own overlapping
but unequal sets (chao has no `cgroup-root` or `seccomp-root`; the DaemonSet has no
`chao-tls-identity`), so per-workload lists would be strictly more precise. Rejected: it doubles the lists to maintain,
diverges from `CLAUDE.md`'s single list, and its only effect is to *permit* a user to name a chao
volume `cgroup-root` — a name the chart owns semantically, which nobody has asked to use. One
list is the simpler thing that satisfies the requirement. The container list matches the
requirements' literal wording (`seccomp-init`, `gremlin`, `chao`) for both workloads.

**Static, not derived.** GPU vendor volume names and container-driver socket names are
values-driven (`gremlin.gpu.<vendor>.volumes`, `containerDrivers.<key>.name`), so a template could
union them in at render time. Rejected as speculative: the shipped `nvidia`/`amd`/`custom` blocks
and the three shipped drivers are already covered by the static list above, and a hand-configured
GPU vendor block colliding with a hand-written `extraVolumes` entry is a scenario nobody has hit.
A static list is also predictable, testable, and documentable, and it does not make turning on
GPU support retroactively invalidate a values file.

**Deliverables in `CLAUDE.md`** (both in its reserved-name section):

1. **Outstanding.** Record the known gap — names introduced by a hand-configured
   `gremlin.gpu.<vendor>` block are not covered by the check, and a collision there surfaces as a
   Kubernetes API rejection. Whoever adds a vendor block adds its names to the list, which is what
   the file's existing "How to apply" rule already says.
2. **Done** (applied 2026-09-17, ahead of this revision). `extraEnv` moved out of the rule's
   scope — see §9.

### 5.6 Failure message format

One `printf`, shared by all six call sites:

```
<valuePath>: %q collides with a <kind> name the gremlin chart manages. Rename it.
```

Worked examples:

- `extraVolumes: "gremlin-state" collides with a volume name the gremlin chart manages. Rename it.`
- `chao.initContainers: "chao" collides with a container name the gremlin chart manages. Rename it.`
- `chao.extraVolumeMounts: "gremlin-cert" collides with a volume name the gremlin chart manages. Rename it.`

Properties this format is chosen for:

- It names the colliding name (B2 and B3 both require this) **and** the value path, so an operator
  with both a root and a `chao.*` list set knows which one to edit.
- It does not enumerate the full reserved list, which would make every probe brittle against any
  future addition to that list.
- `%q` quotes the name, so an empty or whitespace name is still visible in the output.
- The `kind` word is grammatical in context: `volume`, `container`.

Checks fail on the **first** collision found, not an aggregate. A second collision surfaces on the
next render. This matches `chaoNamespacesValidate` and keeps the message a single stable string
that `failedTemplate: {errorMessage: ...}` can match exactly.

---

## 6. Why no chart-side schema validation

Every field except the collision-checked names is `toYaml`'d straight through. A malformed
`Probe`, `Lifecycle`, or `HostAlias` is rejected by the Kubernetes API at apply time with the
API's own error. This is the binding constraint from the requirements and matches how the chart
already treats `gremlin.extraEnv`, `gremlin.resources`, `affinity`, and the GPU vendor blocks.

Consequence for implementers: do not add `required`, type coercion, or shape assertions to any of
the twelve values.

---

## 7. Backward compatibility

The binding constraint is byte-identical output when every new value is unset. This design
achieves it structurally:

- Eleven of twelve values render under `{{- with }}`, whose `{}`/`[]` defaults are falsy.
- `terminationGracePeriodSeconds` renders under `kindIs "invalid"`, false for its null default.
- The `initContainers` restructure (§3.3) moves the seccomp-init entry verbatim at its existing
  indentation, so with `initContainers` unset the guard reduces to the original condition and the
  bytes are unchanged.
- The chao `volumeMounts:` gate (§4.4) gains a fourth `or` term that is false by default, leaving
  the original three-term result unchanged.
- The collision checks render nothing when they find nothing.

There is no intentional exception. With the `extraEnv` retrofit dropped (§9), **every** values
file that installs cleanly against the current chart installs cleanly against this one, and every
rendered manifest is byte-identical until the operator opts in. Upgrade risk for this change is
nil.

---

## 8. Test plan (helm-unittest, `gremlin/tests/`)

Follow the existing idiom: `suite:`, `templates:`, `release:`, `tests:` with `set:` and explicit
path `asserts:`. **No snapshots** — this chart has none (`gremlin/tests/__snapshot__/` is empty)
and uses explicit path assertions everywhere.

Proposed files:

| File | Covers |
|---|---|
| `daemonset_podspec_test.yaml` | B1, B4, B5, B6, B7, B8, B9 on the DaemonSet — each set, each asserted at its rendered path; plus `notExists` for every field in the default case |
| `daemonset_extra_volumes_test.yaml` | B3 on the DaemonSet — appended volume and mount present; ordering after the chart-managed entries; default unchanged |
| `daemonset_init_containers_test.yaml` | B2 on the DaemonSet — user containers with seccomp off; with seccomp on, `seccomp-init` at index 0 and the user's at index 1; `notExists` on `initContainers` by default with seccomp off |
| `chao_deployment_podspec_test.yaml` | B1, B2, B4, B5, B6, B7, B8, B9 on chao, same shape |
| `chao_deployment_extra_volumes_test.yaml` | B3 on chao — **including the case where none of the three existing `volumeMounts:` gate conditions hold** (secret-type auth, no `ssl.certFile`, no TLS identity) and `chao.extraVolumeMounts` alone must bring the key into existence |
| `reserved_names_test.yaml` | B2/B3 rejects on both workloads — `failedTemplate: {errorMessage: ...}` per §5.6, plus `notFailedTemplate` for non-colliding names, **and** a case setting `gremlin.extraEnv`/`chao.extraEnv` to a chart-managed name asserting the render still succeeds (guards the §9 decision against silent reintroduction) |

Notes for whoever writes the probes:

- The reject specs target `templates: [daemonset.yaml]` and `templates: [chao-deployment.yaml]`
  directly (the direct-fail pattern), **not** `NOTES.txt`. Follow
  `chao_deployment_namespaces_test.yaml`, not `notes_test.yaml`.
- `terminationGracePeriodSeconds: 0` deserves its own case on at least one workload — it is the
  specific value the `kindIs "invalid"` guard exists for, and a `with`-based implementation would
  pass every other case while failing this one.
- The DaemonSet reject specs should include one case with `gremlin.gpu.enabled: true`, confirming
  the check still fires exactly once and the fan-out renders.
- chao reject specs should include a `chao.create: false` case asserting `hasDocuments: {count: 0}`
  even with a colliding value set, matching the existing namespaces suite's final case.

---

## 9. Resolved — the `extraEnv` retrofit is dropped

**Decision:** drop it. Resolved by Danny Seymour on 2026-09-17; `requirements.md` re-assented the
same day, dropping its old B9 and renumbering pod-level `securityContext` from B10 to B9. This
section is kept as the record of why the chart deliberately does *not* validate `extraEnv`, so
nobody re-adds the check later as an oversight fix.

**What was found during design.** `gremlin.extraEnv` and `chao.extraEnv` render **last** in their
container's `env:` list (`_daemonset.tpl` 207–209; `chao-deployment.yaml` 106–108). Kubernetes
resolves duplicate env names last-wins. So setting `GREMLIN_SERVICE_URL` (or `https_proxy`, or
`SSL_CERT_FILE`) in `extraEnv` is not a bug being tolerated — it is a **working override**, and
for some of those values it is the only override the chart offers.

Retrofitting a hard failure would have turned a green `helm upgrade` red for anyone relying on
that, with no opt-in and no migration path — colliding head-on with the binding constraint that
existing installs see no diff until they opt in. The original requirements assented to the change
having described what it displaced as a silent shadowing accident, without the finding that the
shadowing is load-bearing.

Three options were put to the human: fail unconditionally as originally assented; fail with an
`allowReservedEnvOverrides` escape hatch; or drop the retrofit. **The human chose to drop it.**

**Consequences, all already reflected above:**

- No `gremlin.reservedNames.env` template, and no env-var reserved list transcribed into any
  template (§5.2, §5.5).
- No `extraEnv` call site in `gremlin.validateReservedNames.daemonset` or `.chao` (§5.3).
- No `allowReservedEnvOverrides` value, on either workload.
- `gremlin.extraEnv` and `chao.extraEnv` are not read, moved, renamed, or re-rendered by this
  change. Their render-last position is now load-bearing behavior — anything that reorders the
  `env:` blocks in either template silently removes a supported override.
- The collision check covers `initContainers`, `extraVolumes`, and `extraVolumeMounts` only.
- Upgrade risk for the whole change is nil (§7).

**`CLAUDE.md` amendment — applied 2026-09-17, no action needed.** The file previously said the
fail-fast rule "applies to `extraEnv` too, retrofitted onto the pre-existing value, not just
newly-added values." It now scopes the rule to *new* values only and names `extraEnv` as an
explicit exemption alongside `envFrom`, with the render-last/last-wins rationale and a pointer
back to this section. The env-var name list was kept: it documents what the chart owns and is what
an author consults before choosing a new env var name — it simply has no check behind it.

**Live risk to carry forward.** A user can still shadow a chart-managed env var by accident and
get confusing agent behavior with no warning. The chosen trade is that a silent override is
cheaper than a broken upgrade. If that judgment changes, the escape-hatch option (fail, with an
explicit opt-out list) is the amendment to reach for — not an unconditional fail.
