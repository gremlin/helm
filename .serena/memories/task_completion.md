# Task Completion Checklist

Before considering chart work in this repo done:
1. `helm lint ./gremlin` (and `./gremlin-integrations` if touched) — no errors.
2. `helm template ./gremlin` with a representative set of `--set`/values overrides for whatever
   was changed — confirm rendered YAML is valid and matches intent (no stray `null`/`{}` for
   unset optional fields — see `mem:conventions`).
3. `helm unittest ./gremlin` (and `./gremlin-integrations` if touched) passes — add/update test
   specs under `gremlin/tests/*.yaml` and snapshot fixtures under `gremlin/tests/__snapshot__/`
   for any new conditional branch or value.
4. New user-facing values documented in `values.yaml` following the `# <dotted.path> -` comment
   convention (`mem:conventions`), and chart `README.md` updated if it documents values.
5. If `gremlin/Chart.yaml` version bump is expected for a release PR, confirm with the maintainer
   (not every PR bumps chart version).
