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
`helm upgrade` with no opt-in. (Considered and rejected during EN-11853 design — see that
contract's `design.md` for the full reasoning.)

This also does not apply to `envFrom`: it *references* an existing ConfigMap/Secret by name rather
than defining a new object, and the chart cannot see that object's keys at render time, so there
is nothing to statically collide-check.

Reserved names as of this writing:

- Volumes: `gremlin-state`, `gremlin-executions`, `gremlin-logs`, `cgroup-root`, `seccomp-root`,
  `seccomp-profile`, `gremlin-cert`, `ssl-cert-file`, `gremlin-tls-identity`, `chao-tls-identity`,
  `gremlin-opencl-icd`, plus the container-driver socket volumes (`docker-sock`,
  `containerd-sock`, `crio-sock`) and any GPU vendor volume names (`kfd`, `dri`,
  `opencl-vendors`, ...).
- Env vars: `GREMLIN_TEAM_ID`, `GREMLIN_TEAM_SECRET`, `GREMLIN_TEAM_CERTIFICATE_OR_FILE`,
  `GREMLIN_TEAM_PRIVATE_KEY_OR_FILE`, `GREMLIN_IDENTIFIER`, `GREMLIN_CLIENT_TAGS`,
  `GREMLIN_COLLECT_DNS`, `GREMLIN_SERVICE_URL`, `GREMLIN_PUSH_POD_CIDR_TAGS`,
  `GREMLIN_PUSH_ZONE_CIDR_TAGS`, `https_proxy`, `no_proxy`, `SSL_CERT_FILE`, `SSL_CERT_DIR`,
  `GREMLIN_TLS_IDENTITY_CERTIFICATE`, `GREMLIN_TLS_IDENTITY_PRIVATE_KEY`,
  `GREMLIN_CLUSTER_ID`, and any GPU vendor env vars (e.g. `NVIDIA_VISIBLE_DEVICES`,
  `NVIDIA_DRIVER_CAPABILITIES`).
- Container names (for `initContainers`): `seccomp-init`, and each workload's own container name
  (`gremlin`, `chao`).

**Why:** a silent name collision either gets rejected by the Kubernetes API with an opaque error,
or silently shadows/duplicates a chart-managed resource — both are worse than a clear failure at
`helm template`/`helm install` time naming the conflicting value path.

**How to apply:** whenever a new chart value accepts user-supplied names in this shape, add its
reserved list to the collision check and extend this file's list above.

**Known gap:** the reserved lists above are static. Names introduced by a hand-configured
`gremlin.gpu.<vendor>` block (a custom vendor's `volumes`/`volumeMounts` entries) are not covered
by the check — a collision there surfaces only as a Kubernetes API rejection at apply time, not a
chart-level failure. Whoever adds a vendor block should add its names to the reserved list above.

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
