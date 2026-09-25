#!/usr/bin/env bash
# The one place that knows `helm plugin install` needs `--verify=false` on
# Helm 4 and rejects the flag entirely on Helm 3. Called by hooks/setup.sh
# and by the CI schema job, so the branch exists exactly once.
#
# usage: install-schema-plugin.sh <version>
set -euo pipefail

SCHEMA_PLUGIN_VERSION="${1:?usage: install-schema-plugin.sh <version>}"
PLUGIN_URL=https://github.com/losisin/helm-values-schema-json

if ! command -v helm >/dev/null 2>&1; then
    echo "helm must be installed and on PATH: https://helm.sh/docs/intro/install/" >&2
    exit 1
fi

# Helm 4 added plugin signature verification and refuses an unverifiable
# source by default; Helm 3 has no --verify flag at all. Probe for the flag
# rather than parsing the Helm version: a literal `case "$(helm version)" in
# v4.*)` works today and fails in the unsafe direction on the next major - a
# Helm 5 that keeps --verify would fall through to the default branch, omit
# the flag, and reproduce today's Helm 4 error on a machine nobody has yet.
# Probing degrades safely: a future Helm that renames the flag takes the
# else branch and fails loudly with an install error, rather than guessing
# and proceeding.
#
# Captured to a variable and matched with a `case`, not piped into
# `grep -q`: `grep -q` exits the instant it matches, and if `helm`'s help
# output ever exceeded the pipe buffer it would be killed by SIGPIPE: under
# `set -o pipefail` that reads as "flag not found" and silently drops
# --verify=false - failing in the direction this script exists to prevent.
help_out="$(helm plugin install --help 2>&1 || true)"
verify_flag=()
case "$help_out" in
    *--verify*) verify_flag=(--verify=false) ;;
esac

helm plugin install "$PLUGIN_URL" \
    --version "$SCHEMA_PLUGIN_VERSION" \
    "${verify_flag[@]}"
