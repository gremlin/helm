#!/usr/bin/env bash
# B1 local + CI executor.
#
# Two passes per chart: pure defaults (the cheapest possible proof that
# values.yaml satisfies its own values.schema.json, once one exists), and
# with that chart's ci/linting override (if any), which exercises the paths
# defaults leave dark - managed secrets, PSP/SCC, seccomp, mTLS identity,
# GPU vendors, the _validation.tpl mutual-exclusion checks.
#
# --strict promotes warnings to failures; the pre-existing "icon is
# recommended" INFO does not trip it (verified under both Helm majors).
#
# Deliberately no --quiet: it would suppress the output a contributor needs
# to diagnose a failure.
set -euo pipefail
cd "$(dirname "$0")/.."          # always operate from the repo root

if ! command -v helm >/dev/null 2>&1; then
    echo "helm must be installed and on PATH: https://helm.sh/docs/intro/install/" >&2
    exit 1
fi

status=0

for chart in */Chart.yaml; do
    chart="${chart%/Chart.yaml}"

    echo "==> helm lint --strict $chart"
    if ! helm lint --strict "$chart"; then
        status=1
    fi

    override="ci/linting/$chart.yaml"
    if [ -f "$override" ]; then
        echo "==> helm lint --strict $chart --values $override"
        if ! helm lint --strict "$chart" --values "$override"; then
            status=1
        fi
    fi
done

exit $status
