#!/usr/bin/env bash
# B5 - installs only what is missing. Never uninstalls, replaces or
# upgrades anything: a tool already present is left exactly as found,
# whatever its version. A version differing from the pin produces a
# warning, not a failure, and this script still exits zero - a bootstrap
# command should not mutate tooling a developer installed deliberately.
#
# Sandboxing seam, load-bearing, do not "simplify" away: this script must
# honour HELM_PLUGINS, HELM_DOCS_INSTALL_DIR and PRE_COMMIT_HOME rather than
# hardcoding paths, and must discover every tool through PATH (never an
# absolute path), so a probe can relocate all three and genuinely test the
# "install a missing tool" branch without touching a real machine.
set -euo pipefail
cd "$(dirname "$0")/.."          # always operate from the repo root

SCHEMA_PLUGIN_VERSION="${SCHEMA_PLUGIN_VERSION:-v2.2.0}"
HELM_DOCS_VERSION="${HELM_DOCS_VERSION:-1.14.2}"
schema_pin="${SCHEMA_PLUGIN_VERSION#v}"

warn() {
    echo "warning: $1" >&2
    shift
    for line in "$@"; do
        echo "         $line" >&2
    done
}

# --- 1. Helm itself: required, never installed by this script -----------
if ! command -v helm >/dev/null 2>&1; then
    echo "error: helm is not installed. Contributors are expected to already have it:" >&2
    echo "       https://helm.sh/docs/intro/install/" >&2
    exit 1
fi
helm_version="$(helm version --template '{{.Version}}' 2>/dev/null || echo unknown)"

# --- 2. Schema plugin -----------------------------------------------------
schema_installed="$(helm plugin list 2>/dev/null | awk '$1=="schema"{print $2}')"
if [ -z "$schema_installed" ]; then
    echo "Installing helm-values-schema-json plugin ${SCHEMA_PLUGIN_VERSION}..."
    hooks/install-schema-plugin.sh "$SCHEMA_PLUGIN_VERSION"
    schema_installed="$(helm plugin list 2>/dev/null | awk '$1=="schema"{print $2}')"
    schema_status="pinned"
elif [ "$schema_installed" = "$schema_pin" ]; then
    schema_status="pinned"
else
    schema_status="MISMATCH"
    warn "helm-values-schema-json plugin $schema_installed found, but this repo pins $schema_pin." \
        "Leaving it as-is (make setup never replaces an existing install)." \
        "If 'make schema' produces a values.schema.json diff that CI disagrees with, this" \
        "is the first thing to check. To align: helm plugin uninstall schema && make setup"
fi

# --- 3. helm-docs ----------------------------------------------------------
if ! command -v helm-docs >/dev/null 2>&1; then
    echo "Installing helm-docs ${HELM_DOCS_VERSION}..."
    install_dir="${HELM_DOCS_INSTALL_DIR:-/usr/local/bin}"
    mkdir -p "$install_dir"
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/norwoodj/helm-docs/releases/download/v${HELM_DOCS_VERSION}/helm-docs_${HELM_DOCS_VERSION}_$(uname -s)_$(uname -m).tar.gz" \
        | tar -xz -C "$tmp" helm-docs
    install -m 0755 "$tmp/helm-docs" "$install_dir/helm-docs"
    rm -rf "$tmp"
    docs_installed="$HELM_DOCS_VERSION"
    docs_status="pinned"
else
    docs_installed="$(helm-docs --version 2>&1 | awk '{print $NF}')"
    if [ "$docs_installed" = "$HELM_DOCS_VERSION" ]; then
        docs_status="pinned"
    else
        docs_status="MISMATCH"
        warn "helm-docs $docs_installed found on PATH, but this repo pins $HELM_DOCS_VERSION." \
            "Leaving it as-is (make setup never replaces an existing install)." \
            "If 'make docs' produces a README diff that CI disagrees with, this is the" \
            "first thing to check. To align: brew upgrade norwoodj/tap/helm-docs" \
            "(or see https://github.com/norwoodj/helm-docs/releases/tag/v${HELM_DOCS_VERSION})."
    fi
fi

# --- 4. pre-commit (the binary) --------------------------------------------
if ! command -v pre-commit >/dev/null 2>&1; then
    echo "Installing pre-commit..."
    if command -v pip >/dev/null 2>&1; then
        pip install pre-commit
    elif command -v pip3 >/dev/null 2>&1; then
        pip3 install pre-commit
    elif command -v brew >/dev/null 2>&1; then
        brew install pre-commit
    else
        echo "error: could not install pre-commit automatically (no pip/pip3/brew on PATH)." >&2
        echo "       Install it yourself: https://pre-commit.com/#install" >&2
        exit 1
    fi
fi
precommit_installed="$(pre-commit --version 2>&1 | awk '{print $NF}')"

# --- 5. Register the hooks --------------------------------------------------
pre-commit install

# --- 6. Summary --------------------------------------------------------------
echo
echo "Toolchain summary:"
echo "  helm                        $helm_version"
echo "  helm-values-schema-json     ${schema_installed:-none} ($schema_status)"
echo "  helm-docs                   ${docs_installed:-none} ($docs_status)"
echo "  pre-commit                  $precommit_installed (hooks registered)"
