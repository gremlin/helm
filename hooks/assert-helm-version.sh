#!/usr/bin/env bash
# The matrix-guard script. A matrix leg (or a job resolving two Helm
# binaries at once) that cannot run must fail, never skip or silently fall
# back to PATH - a silently-halved matrix carries the appearance of
# coverage, which is worse than no matrix at all.
#
# Two usages:
#
#   assert-helm-version.sh <expected-version>
#     Confirms the `helm` resolved from PATH reports <expected-version>
#     exactly. One CI matrix leg, one call: if azure/setup-helm ever
#     silently installs something other than what a leg asked for, the leg
#     fails with "expected v4.3.0, got v3.17.0" rather than running the v3
#     engine under a check named "(v4.3.0)".
#
#   assert-helm-version.sh          (no argument)
#     Confirms HELM3_BIN and HELM4_BIN each resolve to a real binary
#     reporting the expected major version. Never falls back to PATH: CI's
#     ambient `helm` is always v3.17.0, so silently letting HELM4_BIN
#     default to PATH would resolve the v3 slot twice while looking like
#     dual-major coverage. An unset, missing, or wrong-major HELM4_BIN (or
#     HELM3_BIN) fails naming that variable specifically.
set -euo pipefail

_major() {
    "$1" version --short 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'
}

if [ "$#" -ge 1 ]; then
    expected="$1"
    if ! command -v helm >/dev/null 2>&1; then
        echo "assert-helm-version: no 'helm' found on PATH (expected $expected)" >&2
        exit 1
    fi
    got="$(helm version --short 2>/dev/null)"
    case "$got" in
        "$expected"*)
            exit 0
            ;;
        *)
            echo "assert-helm-version: expected $expected, got ${got:-nothing}" >&2
            exit 1
            ;;
    esac
fi

# Two-binary mode: HELM3_BIN must report major 3, HELM4_BIN must report
# major 4 - neither is ever looked up on PATH here.
fail=0
for slot in HELM3_BIN:3 HELM4_BIN:4; do
    var="${slot%%:*}"
    want="${slot##*:}"
    val="${!var:-}"

    if [ -z "$val" ]; then
        echo "assert-helm-version: $var is not set - refusing to fall back to PATH" >&2
        fail=1
        continue
    fi
    if [ ! -x "$val" ] && ! command -v "$val" >/dev/null 2>&1; then
        echo "assert-helm-version: $var ($val) does not exist or is not executable" >&2
        fail=1
        continue
    fi

    major="$(_major "$val")"
    if [ "$major" != "$want" ]; then
        echo "assert-helm-version: $var ($val) reports major version ${major:-unknown}, expected $want" >&2
        fail=1
    fi
done

exit $fail
