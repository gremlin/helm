# Chart-Authoring Conventions

- **Named-template context passing**: multi-parameter named templates (e.g. `gremlin.daemonset`,
  `gremlinGpuNodeAffinity`) take a single `dict` argument with a `root` key holding the chart root
  context (`$`), plus named keys for the rest. Inside the template, immediately unpack needed keys
  into `$`-prefixed local vars at the top (`{{- $root := .root -}}` etc.) before use.
- **Optional blocks**: use `{{- if $root.Values.x.y }} ... {{- end }}` to omit a whole YAML key
  when unset, not an empty value — avoids emitting `key: null`/`key: {}` for fields Kubernetes
  treats as "explicitly set." `{{- with .Values.x }}` is used when the block also needs the value
  itself in scope.
- **New extension-point values default to Go zero-value equivalents** (`{}`, `[]`, `""`) in
  `values.yaml`, guarded by a truthy `if`, mirroring `extraEnv: []` / `podAnnotations: {}` /
  `resources: {}` — never a non-empty default that changes existing render output.
- **values.yaml documentation**: every user-facing value is preceded by a comment in the form
  `# <dotted.path> -\n# <description>`, matching the dotted path exactly (e.g.
  `# gremlin.podSecurity.privileged -`). Multi-line explanations continue as plain `#` comments
  indented to match. This convention is relied on by the chart's generated docs — keep new values
  consistent with it.
- **Cross-field validation lives in `_validation.tpl`**, not inline in the resource template: a
  named template (e.g. `chaoNamespacesValidate`, `gremlinTlsIdentityValidate`) calls Helm's `fail`
  with a message naming the conflicting value paths, and is `include`d at the top of the resource
  template that needs the check (e.g. `chao-deployment.yaml` includes `chaoNamespacesValidate`
  before rendering). Pattern: fail fast at `helm install`/`template` time rather than let an
  invalid combination reach a CrashLoopBackOff.
- **gremlin vs. chao asymmetry is deliberate but historical**: `_daemonset.tpl` uses the
  dict-context/named-template pattern and richer helper reuse; `chao-deployment.yaml` is a flatter,
  more repetitive single template. When adding equivalent capabilities to both (e.g. probes,
  extraVolumes), expect to write the logic twice rather than share a template, unless doing a
  deliberate (separately-flagged) refactor — refactoring chao to match gremlin's pattern is a
  distinct, unrequested piece of work per `mem:core`'s note on drift.
- **GPU vendor blocks** (`gremlin.gpu.<vendor>`) are "full, native-shaped" config: `env`,
  `volumes`, `volumeMounts` sub-keys hold literal Kubernetes API fragments merged in via
  `toYaml`/`with`, not chart-specific abstractions — new per-vendor extension fields should follow
  this native-shape convention rather than inventing new field names Kubernetes doesn't have.
