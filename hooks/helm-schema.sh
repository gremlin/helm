#!/usr/bin/env bash
# B2 local + CI executor.
#
# Regenerates every chart's values.schema.json from its .schema.yaml. A chart
# with no .schema.yaml is skipped, not failed - that's what keeps this a
# no-op today, before any chart has one.
#
# Warns, never fails, on a schema-plugin version mismatch. B5 explicitly
# tolerates an unpinned existing install; a hard-failing hook here would
# make `git commit` impossible for exactly the contributor B5 accommodates.
# The drift check (hooks/check-drift.sh) is what actually catches a
# consequential divergence.
set -euo pipefail
cd "$(dirname "$0")/.."          # always operate from the repo root

SCHEMA_PLUGIN_VERSION="${SCHEMA_PLUGIN_VERSION:-v2.2.0}"

if ! command -v helm >/dev/null 2>&1; then
    echo "helm must be installed and on PATH: https://helm.sh/docs/intro/install/" >&2
    exit 1
fi

installed="$(helm plugin list | awk '$1=="schema"{print $2}')"
pinned="${SCHEMA_PLUGIN_VERSION#v}"
if [ -z "$installed" ]; then
    echo "warning: helm-values-schema-json plugin is not installed. Run 'make setup' first." >&2
elif [ "$installed" != "$pinned" ]; then
    echo "warning: helm-values-schema-json plugin $installed found, but this repo pins $pinned." >&2
    echo "         Leaving it as-is (make setup never replaces an existing install)." >&2
    echo "         If 'make schema' produces a values.schema.json diff that CI disagrees" >&2
    echo "         with, this is the first thing to check." >&2
fi

for chart in */Chart.yaml; do
    chart="${chart%/Chart.yaml}"
    [ -f "$chart/.schema.yaml" ] || continue

    echo "==> helm schema --config .schema.yaml ($chart)"
    # helm schema resolves input:/output: relative to the working directory.
    (cd "$chart" && helm schema --config .schema.yaml)
done
