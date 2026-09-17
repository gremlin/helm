# Gremlin Helm Charts — Core

Two independent Helm charts in one repo, no shared parent chart:
- `gremlin/` — the main chart. Renders the Gremlin agent DaemonSet(s) and the `chao` Deployment
  (Kubernetes-targeting sidecar agent). Version pinned in `gremlin/Chart.yaml`.
- `gremlin-integrations/` — separate, smaller chart (own Deployment/serviceaccount/secrets),
  not used by the DaemonSet/chao work.

Within `gremlin/templates/`:
- `daemonset.yaml` decides *how many* DaemonSets exist (GPU fan-out: one per
  `gremlin.gpu.vendors` entry pinned by node affinity, plus a `-gpu-none` catch-all, or a single
  DaemonSet when GPU is disabled) and calls the `gremlin.daemonset` named template once per
  DaemonSet.
- `_daemonset.tpl` defines `gremlin.daemonset`, which renders one DaemonSet body from an
  already-resolved context dict (`root`, `name`, `selectorLabels`, `gpu`, `affinity`). It has no
  GPU-fan-out knowledge itself — pure separation between "how many/which" (daemonset.yaml) and
  "what's in one" (_daemonset.tpl). Any change to the pod/container spec belongs in this template,
  applied once, and automatically covers every fanned-out DaemonSet variant.
- `chao-deployment.yaml` renders the single `chao` Deployment directly (no fan-out, no shared
  named template) — conditioned on `.Values.chao.create`. Historically drifted from the daemonset
  in raw YAML style (heavier use of `{{- if ... }}` blocks without `with`/`toYaml` helpers) and in
  which extension points exist (chao has fewer: no probes, no initContainers, no lifecycle hooks,
  no envFrom, no pod-level securityContext as of the EN-11853 audit).
- `_helpers.tpl` holds named templates: naming (`gremlin.name`/`gremlin.fullname`/`gremlin.chart`),
  secret name/type resolution, container-driver-to-mount-path mapping (`containerMounts` /
  `containerMountsPSP` / `containerVolumes`, keyed off `.Values.containerDrivers`), TLS identity
  (three mutually-exclusive strategies: `remoteSecret` (ARNs) / `createSecret` / `existingSecret`,
  each with its own env/volume/volumeMount/arg builder for both gremlin and chao), and GPU helpers
  (`gremlinGpuNodeAffinity` merges vendor nodeSelectors into the user's `.Values.affinity` as
  `matchExpressions` rather than replacing it).
- `_validation.tpl` is a separate file for `fail`-based cross-value validation — see
  `mem:conventions` for the pattern.

See `mem:tech_stack` for the toolchain, `mem:suggested_commands` for test/lint commands,
`mem:conventions` for chart-authoring conventions specific to this repo, and
`mem:task_completion` for what "done" requires before a PR.
