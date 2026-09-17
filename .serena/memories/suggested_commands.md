# Suggested Commands

Run from repo root unless noted.

- Render a chart's templates locally: `helm template gremlin ./gremlin` (add `--set`/`-f` as
  needed; e.g. `--set gremlin.secret.managed=true --set gremlin.secret.type=secret` to satisfy
  secret-related conditionals during manual testing).
- Run the unittest suite for a chart: `helm unittest ./gremlin` (requires the `helm-unittest`
  plugin installed locally: `helm plugin install https://github.com/helm-unittest/helm-unittest`).
  CI pins unittest-version v1.0.3 and helm v3.17.0 — match those locally if results diverge from CI.
- Regenerate/update snapshot fixtures: helm-unittest supports `-u`/`--update-snapshot`; check
  `helm unittest --help` for the current flag name before relying on it, plugin versions have
  changed this flag before.
- Lint a chart: `helm lint ./gremlin` (not run in CI, but cheap to run before pushing).
- No non-standard forms of common Linux utilities are needed for this repo (plain `git`, `grep`,
  `ls` all behave as expected).
