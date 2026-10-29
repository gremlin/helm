#!/usr/bin/env bash
# Local acceptance test for the gremlin-operator chart. It builds the operator image from a local checkout of the
# operator repository, loads it into a throwaway kind cluster, installs the chart and checks the install and the
# uninstall. It is not run in CI because no operator image is published yet.
#
#   ci/gremlin-operator/kind-test.sh [--scenario install|uninstall|all] [--junit FILE]
#
# Environment:
#   OPERATOR_CHECKOUT  operator repository to build the image from, at the commit in ci/gremlin-operator/operator-ref (default $HOME/workspace/github.com/gremlin/gremlin-operator)
#   CHART_DIR          chart to install (default: gremlin-operator at the repository root)
#   KUBE_CONTEXT       reuse an existing kind context (must start with kind-) instead of creating a cluster
#   IMAGE              reuse an image already loaded in that cluster (repository:tag) instead of building one
#   KEEP_CLUSTER       set to 1 to leave a cluster this script created in place
#
# Nothing here ever talks to a cluster other than a kind cluster: the script keeps its own kubeconfig for the cluster
# it creates, refuses a context that does not start with kind-, and names the context on every kubectl and helm call.
set -euo pipefail

SCENARIO=all
JUNIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --scenario) SCENARIO="${2:?--scenario needs a value}"; shift 2 ;;
    --junit) JUNIT="${2:?--junit needs a file}"; shift 2 ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$SCENARIO" in install|uninstall|all) ;; *) echo "unknown scenario: $SCENARIO" >&2; exit 2 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHART_DIR="${CHART_DIR:-$ROOT/gremlin-operator}"
OPERATOR_CHECKOUT="${OPERATOR_CHECKOUT:-$HOME/workspace/github.com/gremlin/gremlin-operator}"
RELEASE=gremlin-operator
OPERATOR_NS=gremlin-operator-system

WORK="$(mktemp -d)"
CLUSTER=""
CTX=""
CASES=()
FAILURES=0

cleanup() {
  local status=$?
  if [ -n "$CLUSTER" ] && [ "${KEEP_CLUSTER:-0}" != 1 ]; then
    kind delete cluster --name "$CLUSTER" --kubeconfig "$WORK/kubeconfig" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT

die() { echo "kind-test: $*" >&2; exit 2; }

require_kind_context() {
  case "$CTX" in kind-?*) ;; *) die "refusing context '$CTX': it does not start with kind-" ;; esac
}
k() { require_kind_context; kubectl --context "$CTX" "$@"; }
h() { require_kind_context; helm --kube-context "$CTX" "$@"; }

xml_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

# run_case NAME FUNCTION: records one JUnit case; a failure is counted and the run goes on.
run_case() {
  local name="$1" fn="$2" out status
  echo "--- $name"
  # errexit is ignored inside any command run from || or if, so the case body runs in a plain subshell with its own set -e.
  set +e
  ( set -e; "$fn" ) >"$WORK/case.out" 2>&1
  status=$?
  set -e
  out="$(cat "$WORK/case.out")"
  if [ "$status" -eq 0 ]; then
    CASES+=("<testcase classname=\"gremlin-operator-kind\" name=\"$(printf '%s' "$name" | xml_escape)\"/>")
    echo "    ok"
  else
    FAILURES=$((FAILURES + 1))
    echo "$out" | tail -n 20 | sed 's/^/    /'
    CASES+=("<testcase classname=\"gremlin-operator-kind\" name=\"$(printf '%s' "$name" | xml_escape)\"><failure message=\"failed\">$(printf '%s' "$out" | tail -n 40 | xml_escape)</failure></testcase>")
    echo "    FAILED"
  fi
  return 0
}

write_junit() {
  [ -n "$JUNIT" ] || return 0
  mkdir -p "$(dirname "$JUNIT")"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo "<testsuite name=\"gremlin-operator kind acceptance\" tests=\"${#CASES[@]}\" failures=\"$FAILURES\">"
    printf '%s\n' "${CASES[@]}"
    echo '</testsuite>'
  } > "$JUNIT"
}

# 1. Preflight: tools and the operator checkout.
for tool in docker kind kubectl helm; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed"
done
docker info >/dev/null 2>&1 || die "docker is not running"
if [ -z "${IMAGE:-}" ]; then
  [ -f "$OPERATOR_CHECKOUT/Dockerfile" ] || die "no operator Dockerfile at $OPERATOR_CHECKOUT (set OPERATOR_CHECKOUT)"
fi
if [ -n "${KUBE_CONTEXT:-}" ]; then
  CTX="$KUBE_CONTEXT"
  require_kind_context
fi

# 2. Lint the chart before anything is built or created. This call is offline and needs no cluster.
echo "--- helm lint --strict"
helm lint --strict "$CHART_DIR" || die "helm lint failed for $CHART_DIR"

# 3. Image and cluster. An image built here comes from the operator commit the repository pins.
if [ -n "${IMAGE:-}" ]; then
  IMAGE_REPO="${IMAGE%:*}"
  IMAGE_TAG="${IMAGE##*:}"
else
  PIN_FILE="$ROOT/ci/gremlin-operator/operator-ref"
  [ -f "$PIN_FILE" ] || die "no $PIN_FILE: the operator commit to build is not pinned"
  PINNED="$(tr -d '[:space:]' < "$PIN_FILE")"
  OPERATOR_HEAD="$(git -C "$OPERATOR_CHECKOUT" rev-parse HEAD)" || die "$OPERATOR_CHECKOUT is not a git checkout"
  case "$OPERATOR_HEAD" in "$PINNED"*) ;; *) die "operator checkout is at $OPERATOR_HEAD but operator-ref pins $PINNED" ;; esac
  IMAGE_REPO=example.com/gremlin-operator
  IMAGE_TAG="chart-test-$RANDOM$RANDOM"
  echo "--- docker build $IMAGE_REPO:$IMAGE_TAG"
  docker build -t "$IMAGE_REPO:$IMAGE_TAG" "$OPERATOR_CHECKOUT" >"$WORK/build.log" 2>&1 \
    || { tail -n 30 "$WORK/build.log" >&2; die "image build failed"; }
fi

if [ -z "$CTX" ]; then
  CLUSTER="gremlin-operator-chart-$RANDOM$RANDOM"
  CTX="kind-$CLUSTER"
  echo "--- kind create cluster $CLUSTER"
  kind create cluster --name "$CLUSTER" --kubeconfig "$WORK/kubeconfig" --wait 120s >"$WORK/kind.log" 2>&1 \
    || { tail -n 30 "$WORK/kind.log" >&2; die "kind create cluster failed"; }
  # Every later kubectl and helm call reads only this kubeconfig, so the default one is never consulted.
  export KUBECONFIG="$WORK/kubeconfig"
  echo "--- kind load docker-image"
  kind load docker-image "$IMAGE_REPO:$IMAGE_TAG" --name "$CLUSTER" >"$WORK/load.log" 2>&1 \
    || { tail -n 30 "$WORK/load.log" >&2; die "kind load failed"; }
fi
require_kind_context

if [ -z "${IMAGE:-}" ] && [ -z "$CLUSTER" ]; then
  # A reused kind cluster does not have the image this run built.
  echo "--- kind load docker-image (reused cluster ${CTX#kind-})"
  kind load docker-image "$IMAGE_REPO:$IMAGE_TAG" --name "${CTX#kind-}" >"$WORK/load.log" 2>&1 \
    || { tail -n 30 "$WORK/load.log" >&2; die "kind load failed"; }
fi

install_chart() {
  h install "$RELEASE" "$CHART_DIR" --namespace "$OPERATOR_NS" --create-namespace \
    --set image.repository="$IMAGE_REPO" --set image.tag="$IMAGE_TAG" --wait
}

case_install_succeeds() { install_chart; }

case_crds_established() {
  local crd
  for crd in agents healthchecks reliabilityservices teamcredentials; do
    k wait --for=condition=Established "crd/$crd.gremlin.com" --timeout=60s
    [ "$(k get crd "$crd.gremlin.com" -o jsonpath='{.spec.group}/{.spec.versions[0].name}')" = "gremlin.com/v1alpha1" ] \
      || { echo "crd $crd is not gremlin.com/v1alpha1"; return 1; }
  done
}

case_two_deployments_available() {
  local deployments d
  deployments="$(k -n "$OPERATOR_NS" get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)"
  [ "$deployments" = "$(printf 'gremlin-operator-controller-manager\ngremlin-operator-credential-manager')" ] \
    || { echo "unexpected Deployments:"; echo "$deployments"; return 1; }
  for d in gremlin-operator-controller-manager gremlin-operator-credential-manager; do
    [ "$(k -n "$OPERATOR_NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}')" = 1 ] \
      || { echo "$d has no ready pod"; return 1; }
    [ "$(k -n "$OPERATOR_NS" get deployment "$d" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')" = True ] \
      || { echo "$d is not Available"; return 1; }
  done
}

case_each_process_runs_under_its_own_service_account() {
  local pods expected
  pods="$(k -n "$OPERATOR_NS" get pods -o jsonpath='{range .items[*]}{.spec.serviceAccountName} {.spec.containers[0].command[0]} {.status.containerStatuses[0].ready}{"\n"}{end}' | sort)"
  expected="$(printf 'gremlin-operator-controller-manager /reconciler true\ngremlin-operator-credential-manager /credential-manager true')"
  [ "$pods" = "$expected" ] || { echo "pods are:"; echo "$pods"; echo "expected:"; echo "$expected"; return 1; }
}

case_secret_in_credential_namespace() {
  k -n gremlin-system create secret generic uninstall-probe --from-literal=token=keep-me
}

case_uninstall_succeeds() { h uninstall "$RELEASE" --namespace "$OPERATOR_NS" --wait; }

case_namespaces_and_secret_survive_uninstall() {
  k get namespace gremlin-system gremlin >/dev/null
  [ "$(k -n gremlin-system get secret uninstall-probe -o jsonpath='{.data.token}' | base64 -d)" = keep-me ] \
    || { echo "the Secret in gremlin-system changed or is gone"; return 1; }
}

case_release_objects_are_removed() {
  local left
  left="$(k -n "$OPERATOR_NS" get deployments,serviceaccounts,roles,rolebindings,services,networkpolicies -o name | grep -E 'gremlin-operator-' || true)"
  [ -z "$left" ] || { echo "left in $OPERATOR_NS:"; echo "$left"; return 1; }
  left="$(k get roles,rolebindings,serviceaccounts -n gremlin-system -o name | grep -E 'gremlin-operator-' || true)"
  [ -z "$left" ] || { echo "left in gremlin-system:"; echo "$left"; return 1; }
  left="$(k get roles,rolebindings,serviceaccounts -n gremlin -o name | grep -E 'gremlin-operator-|gremlin-agent|gremlin-chao' || true)"
  [ -z "$left" ] || { echo "left in gremlin:"; echo "$left"; return 1; }
  left="$(k get roles,rolebindings -n default -o name | grep -E 'gremlin-operator-' || true)"
  [ -z "$left" ] || { echo "left in default:"; echo "$left"; return 1; }
}

case_cluster_scoped_bindings_are_removed() {
  local left
  left="$(k get clusterroles,clusterrolebindings -o name | grep -E 'gremlin-operator-' || true)"
  [ -z "$left" ] || { echo "cluster-scoped objects left:"; echo "$left"; return 1; }
}

if [ "$SCENARIO" = install ] || [ "$SCENARIO" = all ]; then
  run_case "helm install of the chart with default values succeeds and waits for both Deployments" case_install_succeeds
  run_case "the four Gremlin CRDs are established" case_crds_established
  run_case "two Deployments are available, one for each operator process" case_two_deployments_available
  run_case "each process runs its own command under its own ServiceAccount with a ready pod" case_each_process_runs_under_its_own_service_account
fi

if [ "$SCENARIO" = uninstall ] || [ "$SCENARIO" = all ]; then
  if [ "$SCENARIO" = uninstall ]; then
    run_case "helm install of the chart with default values succeeds and waits for both Deployments" case_install_succeeds
  fi
  run_case "a credential Secret is created in gremlin-system" case_secret_in_credential_namespace
  run_case "helm uninstall succeeds" case_uninstall_succeeds
  run_case "the credential and install namespaces and the Secret remain after uninstall" case_namespaces_and_secret_survive_uninstall
  run_case "the release's namespaced objects are removed by uninstall" case_release_objects_are_removed
  run_case "the cluster-scoped roles and bindings, including the agent and Chao bindings, are removed by uninstall" case_cluster_scoped_bindings_are_removed
fi

write_junit
echo "$((${#CASES[@]} - FAILURES)) of ${#CASES[@]} cases passed"
[ "$FAILURES" -eq 0 ]
