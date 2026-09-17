# Tech Stack

- Helm charts only (apiVersion: v1, i.e. Helm 2/3-compatible chart format) — no application code
  in this repo. Templates are Go templates (Sprig functions available: `default`, `toYaml`,
  `nindent`, `trimSuffix`, `hasPrefix`, `deepCopy`, etc.).
- Testing: `helm-unittest` (the `d3adb5/helm-unittest-action` plugin), run via GitHub Actions on
  every PR (`.github/workflows/unittest.yml`). Pinned versions: helm v3.17.0, unittest-version
  v1.0.3. Test specs live under `gremlin/tests/*.yaml`; expected-output fixtures under
  `gremlin/tests/__snapshot__/`.
- No linting job beyond helm-unittest in CI (no `helm lint` / chart-testing step observed).
- Two charts published from this repo to the `https://helm.gremlin.com/` chart repo:
  `gremlin` and `gremlin-integrations` (see root `README.md` for install commands).
