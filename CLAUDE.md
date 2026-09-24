# Gremlin Helm Charts — Repo Conventions

## Reserved-name collisions must fail fast

Any *new* chart value that lets a user **define** a named Kubernetes fragment alongside
chart-managed resources of the same kind — `extraVolumes`, `extraVolumeMounts`, `initContainers`,
and any future value of this shape — must fail the template render (via a `_validation.tpl`-style
`fail` check, included at the top of the resource template) when the user-supplied name collides
with a name the chart itself already owns.

This does not apply retroactively to `extraEnv`. It's pre-existing, and `extraEnv` renders last in
both containers' `env:` lists, so a collision there is Kubernetes' documented last-wins override
behavior — a real, working use case (e.g. overriding `GREMLIN_SERVICE_URL` or `https_proxy`), not
a bug. Retrofitting a hard failure onto it would break existing installs on their next
`helm upgrade` with no opt-in.

This also does not apply to `envFrom`: it *references* an existing ConfigMap/Secret by name rather
than defining a new object, and the chart cannot see that object's keys at render time, so there
is nothing to statically collide-check.

**The DaemonSet and Chao Deployment each get their own reserved list, not one shared list.** They
render different chart-managed resources, and checking a workload's `extraVolumes`/`initContainers`
against the *other* workload's names produces false rejections (Chao doesn't render `gremlin-state`,
the DaemonSet doesn't render `chao-tls-identity`, and so on).

Reserved names as of this writing:

- DaemonSet volumes: `gremlin-state`, `gremlin-executions`, `gremlin-logs`, `cgroup-root`,
  `seccomp-root`, `seccomp-profile`, `gremlin-cert`, `ssl-cert-file`, `gremlin-tls-identity`,
  `gremlin-opencl-icd`, `kfd`, `dri`, `opencl-vendors`, plus the container-driver socket volumes
  (derived from `.Values.containerDrivers.*.name` at render time, not hardcoded — currently
  `docker-sock`, `containerd-sock`, `crio-sock`).
- DaemonSet container names (for `initContainers`): `seccomp-init`, `gremlin`.
- Chao volumes: `gremlin-cert`, `ssl-cert-file`, `chao-tls-identity`.
- Chao container names (for `initContainers`): `chao`.
- Env vars (not currently checked — see `envFrom`/`extraEnv` above): `GREMLIN_TEAM_ID`,
  `GREMLIN_TEAM_SECRET`, `GREMLIN_TEAM_CERTIFICATE_OR_FILE`, `GREMLIN_TEAM_PRIVATE_KEY_OR_FILE`,
  `GREMLIN_IDENTIFIER`, `GREMLIN_CLIENT_TAGS`, `GREMLIN_COLLECT_DNS`, `GREMLIN_SERVICE_URL`,
  `GREMLIN_PUSH_POD_CIDR_TAGS`, `GREMLIN_PUSH_ZONE_CIDR_TAGS`, `https_proxy`, `no_proxy`,
  `SSL_CERT_FILE`, `SSL_CERT_DIR`, `GREMLIN_TLS_IDENTITY_CERTIFICATE`,
  `GREMLIN_TLS_IDENTITY_PRIVATE_KEY`, `GREMLIN_CLUSTER_ID`, and any GPU vendor env vars (e.g.
  `NVIDIA_VISIBLE_DEVICES`, `NVIDIA_DRIVER_CAPABILITIES`).

**Why:** a silent name collision either gets rejected by the Kubernetes API with an opaque error,
or silently shadows/duplicates a chart-managed resource — both are worse than a clear failure at
`helm template`/`helm install` time naming the conflicting value path.

**How to apply:** whenever a new chart value accepts user-supplied names in this shape, add its
name to the correct workload's reserved list (`gremlin.reservedNames.daemonset*` /
`.chao*` in `_validation.tpl`) and to this file's list above. Prefer deriving a reserved name from
its source value (as the container-driver sockets do) over hardcoding it, when the source is a
small, fixed-shape values block — hardcoding only the GPU vendor gap below because that block's
shape is genuinely open-ended.

**Known gap:** `gremlin.gpu.<vendor>` blocks are still static. A hand-configured vendor's
`volumes`/`volumeMounts` entries are not covered by the check — a collision there surfaces only as
a Kubernetes API rejection at apply time, not a chart-level failure. Whoever adds a vendor block
should add its names to the reserved list above.

## Name test files after the behavior, not the ticket

`gremlin/tests/*.yaml` files (and their `suite:` descriptions) describe what they test, not which
ticket introduced them — e.g. `extra_volumes_test.yaml` / `suite: extraVolumes / extraVolumeMounts`,
not `en-12345_extra_volumes_test.yaml` / `suite: EN-12345 - extraVolumes`.

**Why:** a ticket ID tells a future reader nothing about what broke, and outlives its usefulness
the moment the ticket is closed — the test itself is what has to stay legible.

**How to apply:** when adding tests for a ticket, name the file and suite for the behavior under
test, matching the existing style (`daemonset_resources_test.yaml`,
`chao_deployment_namespaces_test.yaml`, ...). Keep ticket context in the commit message and PR
description instead.

## Don't reference internal tickets or design docs in repo-committed files

This repo (and this file) is public-facing. Don't cite a Jira ticket key, an internal contract
slug, or a path like `.claude/contracts/<slug>/design.md` in `CLAUDE.md`, `README.md`, code
comments, or `values.yaml` doc comments — describe the reasoning in prose instead of pointing at
where it was decided.

**Why:** a ticket or internal-tooling reference is meaningless to anyone outside the team, and it
rots the moment that tooling's working state is cleaned up or the ticket is closed — a design
rationale should stand on its own, not depend on a link that may not resolve for the reader, or at
all.

**How to apply:** when explaining *why* a decision was made, restate the reasoning directly (as
this file already does above for the `extraEnv` exemption). Ticket numbers and links to
in-progress design artifacts belong in the commit message and PR description, not in
repo-committed files.

## Contract working files stay out of this repository

Agent workflows that produce a contract, design document, requirements document or validation
records under `.claude/contracts/` must keep those files **local and untracked here**.
`.gitignore` excludes the directory; do not re-include it, and do not commit its contents.

This overrides the default those workflows ship with, which is to commit the contract as a
shared audit trail. That default is right for a private repository and wrong for this one.

**Why:** those documents are dense with exactly what the section above forbids — Jira keys,
internal tooling paths, and design rationale written for people inside the team. Committing
them here publishes all of it, and the audit-trail argument for doing so does not outweigh
that when the repository is public. The evidence that matters to an outside reader is the
tests in `tests/`, which stand on their own.

**How to apply:** let the contract live at `.claude/contracts/<slug>/` on disk so the tooling
keeps working unchanged, and carry any reasoning a future reader needs into the commit message,
the pull request description, or this file — restated in prose, never as a pointer to a path
that does not exist in the repository. Executable probes under `tests/` are a different matter
and belong in the repository, but they must not cite contract or design-document paths either,
for the same reason.
