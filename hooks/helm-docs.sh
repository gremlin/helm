#!/usr/bin/env bash
# B4 local + CI executor.
#
# Regenerates each chart's README.md from its README.md.gotmpl + values.yaml.
#
# Deviation from the original sketch, found by actually running this: a bare
# `helm-docs --chart-search-root=.` regenerates EVERY chart it finds, and a
# chart with no README.md.gotmpl falls back to helm-docs' own default
# template - overwriting a hand-written README wholesale rather than leaving
# it alone. That is not a no-op, it is the single most destructive thing this
# script could do before a chart has adopted a .gotmpl. `--chart-to-generate`
# is what makes "no .gotmpl yet" a genuine no-op: only charts that have one
# are named on that list, mirroring how hooks/helm-schema.sh only touches
# charts that have a .schema.yaml.
#
# Warns, never fails, on a helm-docs version mismatch, for the same reason as
# hooks/helm-schema.sh: B5 tolerates an unpinned existing install, so a
# hard-failing hook here would block `git commit` for exactly the contributor
# B5 exists to accommodate.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."          # always operate from the repo root

HELM_DOCS_VERSION="${HELM_DOCS_VERSION:-1.14.2}"

if ! command -v helm-docs >/dev/null 2>&1; then
    echo "helm-docs must be installed and on PATH: https://github.com/norwoodj/helm-docs" >&2
    exit 1
fi

found="$(helm-docs --version 2>&1 | awk '{print $NF}')"
if [ "$found" != "$HELM_DOCS_VERSION" ]; then
    echo "warning: helm-docs $found found on PATH, but this repo pins $HELM_DOCS_VERSION." >&2
    echo "         Leaving it as-is (make setup never replaces an existing install)." >&2
    echo "         If 'make docs' produces a README diff that CI disagrees with, this is" >&2
    echo "         the first thing to check." >&2
fi

charts=()
for chart in */Chart.yaml; do
    chart="${chart%/Chart.yaml}"
    [ -f "$chart/README.md.gotmpl" ] && charts+=("$chart")
done

if [ "${#charts[@]}" -eq 0 ]; then
    exit 0
fi

joined="$(IFS=,; echo "${charts[*]}")"
echo "==> helm-docs --chart-search-root=. --chart-to-generate=$joined"
helm-docs --chart-search-root=. --chart-to-generate="$joined"
