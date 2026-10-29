#!/usr/bin/env python3
"""Keep the gremlin-operator chart equal to the operator's own install output.

  drift.py sync --operator DIR
      Build every scenario with the operator checkout's bin/kustomize and write expected/<scenario>.yaml and the CRD
      files in gremlin-operator/crds/. The checkout must be at the commit in operator-ref. Nothing is written into it.

  drift.py check [--chart DIR] [--junit FILE]
      Render the chart for every scenario and compare it with expected/<scenario>.yaml, then check that values.yaml
      offers no value that defines a volume, volume mount, init container or sidecar. Exit 1 on any difference.

The comparison keys objects by (kind, namespace, name) and compares whole objects, except:
  - metadata labels and annotations, container image and imagePullPolicy are ignored;
  - the pod template's labels and annotations must carry every key the operator sets, with the same value; keys only
    the chart sets are ignored;
  - empty lists and maps are dropped, and container args are compared as sorted lists;
  - the operator's own Namespace is ignored, because the chart installs into the Helm release namespace.
Each Service selector and NetworkPolicy podSelector must also match the pod template of a Deployment in its namespace.
"""
import argparse
import copy
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_CHART = REPO / "gremlin-operator"
OPERATOR_NAMESPACE = "gremlin-operator-system"
RELEASE_NAME = "gremlin-operator"
VALUES_CASE = "values-offer-no-named-fragments"
FRAGMENT_KEY = re.compile(r"(?i)(volume|initcontainer|sidecar|extracontainer)")
TRUNCATE = 300

RESTRICTED_NAMESPACES = ["gremlin", "team-b"]
RESTRICTED_PATCHES = """patches:
- target: {kind: ClusterRoleBinding, name: gremlin-operator-credential-manager-cluster-rolebinding}
  patch: |-
    $patch: delete
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: gremlin-operator-credential-manager-cluster-rolebinding
- target: {kind: Deployment, name: gremlin-operator-credential-manager}
  patch: |-
    - op: test
      path: /spec/template/spec/containers/0/name
      value: manager
    - op: add
      path: /spec/template/spec/containers/0/args/-
      value: --credential-namespaces=gremlin,gremlin-system,team-b
"""

# resources: operator directories to build; readonly_namespaces: namespaces that get config/credential-namespace-readonly
SCENARIOS = {
    "default": {"resources": ["config/deploy"]},
    "restricted": {"resources": ["config/deploy"], "readonly_namespaces": RESTRICTED_NAMESPACES,
                   "patches": RESTRICTED_PATCHES},
}


class DriftError(Exception):
    """The tool cannot do its job (missing file, failed build); distinct from a drift finding."""


def run(cmd):
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as err:
        raise DriftError(f"cannot run {cmd[0]}: {err}")
    if proc.returncode != 0:
        raise DriftError(f"{' '.join(str(c) for c in cmd[:3])} failed:\n{proc.stderr.strip()}")
    return proc.stdout


def load_docs(text):
    return [d for d in yaml.safe_load_all(text) if d]


def object_key(doc):
    meta = doc.get("metadata", {})
    return (doc["kind"], meta.get("namespace", ""), meta["name"])


def prune(value):
    """Drop empty maps and lists from dict values, at every depth."""
    if isinstance(value, dict):
        out = {k: prune(v) for k, v in value.items()}
        return {k: v for k, v in out.items() if v not in ({}, [])}
    if isinstance(value, list):
        return [prune(v) for v in value]
    return value


def pod_template(doc):
    spec = doc.get("spec")
    return (spec.get("template") or {}) if isinstance(spec, dict) else {}


def pod_template_maps(doc):
    meta = pod_template(doc).get("metadata") or {}
    return {"labels": meta.get("labels") or {}, "annotations": meta.get("annotations") or {}}


def normalize(doc):
    doc = copy.deepcopy(doc)
    meta = doc.get("metadata", {})
    meta.pop("labels", None)
    meta.pop("annotations", None)
    template = pod_template(doc)
    template_meta = template.get("metadata") or {}
    template_meta.pop("labels", None)
    template_meta.pop("annotations", None)
    if doc["kind"] == "Deployment":
        for container in (template.get("spec") or {}).get("containers", []):
            container.pop("image", None)
            container.pop("imagePullPolicy", None)
            if "args" in container:
                container["args"] = sorted(container["args"])
    return prune(doc)


def show(value):
    text = str(value)
    return text if len(text) <= TRUNCATE else text[:TRUNCATE] + "..."


def diff(chart_value, operator_value, path=""):
    """Yield (field path, chart value, operator value) for every leaf that differs."""
    if isinstance(chart_value, dict) and isinstance(operator_value, dict):
        for k in sorted(set(chart_value) | set(operator_value)):
            yield from diff(chart_value.get(k), operator_value.get(k), f"{path}.{k}" if path else str(k))
    elif (isinstance(chart_value, list) and isinstance(operator_value, list)
          and len(chart_value) == len(operator_value)):
        for i, (a, b) in enumerate(zip(chart_value, operator_value)):
            yield from diff(a, b, f"{path}[{i}]")
    elif chart_value != operator_value:
        yield path, chart_value, operator_value


def compare(scenario, chart_docs, operator_docs):
    """Report lines for every difference between the chart's objects and the operator's."""
    ignored = ("Namespace", "", OPERATOR_NAMESPACE)
    chart = {object_key(d): d for d in chart_docs if object_key(d) != ignored}
    operator = {object_key(d): d for d in operator_docs if object_key(d) != ignored}
    lines = []
    for key in sorted(set(chart) | set(operator)):
        kind, namespace, name = key
        where = f"{scenario} {kind} {namespace}/{name}"
        if key not in operator:
            lines.append(f"{where}: only in the chart")
            continue
        if key not in chart:
            lines.append(f"{where}: only in the operator's output")
            continue
        if kind == "Deployment":
            mine, wanted = pod_template_maps(chart[key]), pod_template_maps(operator[key])
            for field in ("labels", "annotations"):
                for k, v in sorted(wanted[field].items()):
                    if mine[field].get(k) != v:
                        lines.append(f"{where} spec.template.metadata.{field}.{k}: "
                                     f"chart={mine[field].get(k)} operator={v}")
        for path, a, b in diff(normalize(chart[key]), normalize(operator[key])):
            lines.append(f"{where} {path}: chart={show(a)} operator={show(b)}")
    return lines


def selector_guard(scenario, chart_docs):
    """Report each Service selector and NetworkPolicy podSelector that no Deployment pod template in its namespace
    satisfies. Empty and matchExpressions selectors are reported too: the guard does not evaluate them."""
    pods = [(d["metadata"].get("namespace", ""), pod_template_maps(d)["labels"])
            for d in chart_docs if d["kind"] == "Deployment"]
    lines = []
    for doc in chart_docs:
        if doc["kind"] == "Service":
            field, wanted = "spec.selector", doc.get("spec", {}).get("selector")
        elif doc["kind"] == "NetworkPolicy":
            field = "spec.podSelector"
            selector = doc.get("spec", {}).get("podSelector") or {}
            wanted = None if selector.get("matchExpressions") else selector.get("matchLabels")
        else:
            continue
        namespace = doc["metadata"].get("namespace", "")
        matched = wanted and any(ns == namespace and all(labels.get(k) == v for k, v in wanted.items())
                                 for ns, labels in pods)
        if not matched:
            lines.append(f"{scenario} {doc['kind']} {namespace}/{doc['metadata']['name']} {field}: "
                         "matches no Deployment pod")
    return lines


def fragment_keys(values):
    """Dotted paths of every key, at any depth, whose name suggests a volume, init container or sidecar."""
    found = []

    def walk(node, path):
        if isinstance(node, dict):
            for k, v in node.items():
                here = path + [str(k)]
                if FRAGMENT_KEY.search(str(k)):
                    found.append(".".join(here))
                walk(v, here)
        elif isinstance(node, list):
            for item in node:
                walk(item, path)

    walk(values, [])
    return found


def values_shape_problems(chart):
    path = Path(chart) / "values.yaml"
    try:
        values = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except OSError as err:
        raise DriftError(f"cannot read {path}: {err}")
    return [f"{VALUES_CASE} {path.name} {key}: values must not define volumes, volume mounts, init containers or "
            "sidecars until the value comes with a collision check against the names the chart owns"
            for key in fragment_keys(values)]


def helm_render(chart, values_file):
    text = run(["helm", "template", RELEASE_NAME, str(chart), "--namespace", OPERATOR_NAMESPACE,
                "--include-crds", "-f", str(values_file)])
    return load_docs(text)


def check_scenario(name, chart):
    values_file, expected_file = HERE / "values" / f"{name}.yaml", HERE / "expected" / f"{name}.yaml"
    for required in (values_file, expected_file):
        if not required.is_file():
            return [f"{name}: {required.relative_to(REPO)} does not exist"]
    try:
        chart_docs = helm_render(chart, values_file)
    except DriftError as err:
        return [f"{name}: {err}"]
    operator_docs = load_docs(expected_file.read_text(encoding="utf-8"))
    return compare(name, chart_docs, operator_docs) + selector_guard(name, chart_docs)


def write_junit(path, results):
    suite = ET.Element("testsuite", name="operator-drift", tests=str(len(results)),
                       failures=str(sum(1 for lines in results.values() if lines)))
    for name, lines in results.items():
        case = ET.SubElement(suite, "testcase", classname="operator-drift", name=name)
        if lines:
            failure = ET.SubElement(case, "failure", message=f"{len(lines)} difference(s)")
            failure.text = "\n".join(lines)
    ET.ElementTree(suite).write(path, encoding="utf-8", xml_declaration=True)


def cmd_check(args):
    chart = Path(args.chart)
    if not (chart / "Chart.yaml").is_file():
        raise DriftError(f"{chart} is not a chart directory")
    results = {name: check_scenario(name, chart) for name in SCENARIOS}
    results[VALUES_CASE] = values_shape_problems(chart)
    if args.junit:
        write_junit(args.junit, results)
    problems = [line for lines in results.values() for line in lines]
    if problems:
        print("\n".join(problems))
        return 1
    print(f"no drift in {len(SCENARIOS)} scenarios, and the values offer no named fragments")
    return 0


def pinned_head():
    return (HERE / "operator-ref").read_text(encoding="utf-8").strip()


def require_pinned_checkout(operator):
    pin = pinned_head()
    head = run(["git", "-C", str(operator), "rev-parse", "HEAD"]).strip()
    if head != pin:
        raise DriftError(f"the operator checkout is at {head} but operator-ref pins {pin}")
    if run(["git", "-C", str(operator), "status", "--porcelain", "--untracked-files=no", "--", "config"]).strip():
        raise DriftError("the operator checkout has uncommitted changes under config/")


def kustomize_build(operator, spec):
    """Build a scenario through an overlay outside the checkout that reaches it by symlink."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "op").symlink_to(operator)
        (tmp / "overlay").mkdir()
        lines = ["resources:"] + [f"- ../op/{r}" for r in spec["resources"]]
        for namespace in spec.get("readonly_namespaces", []):
            (tmp / f"ns-{namespace}").mkdir()
            (tmp / f"ns-{namespace}" / "kustomization.yaml").write_text(
                f"namespace: {namespace}\nresources:\n- ../op/config/credential-namespace-readonly\n",
                encoding="utf-8")
            lines.append(f"- ../ns-{namespace}")
        (tmp / "overlay" / "kustomization.yaml").write_text(
            "\n".join(lines) + "\n" + spec.get("patches", ""), encoding="utf-8")
        return run([str(operator / "bin" / "kustomize"), "build", str(tmp / "overlay")])


def split_documents(text):
    return [part for part in re.split(r"(?m)^---\n", text) if part.strip()]


def cmd_sync(args):
    operator = Path(args.operator).resolve()
    if not (operator / "bin" / "kustomize").is_file():
        raise DriftError(f"no bin/kustomize in the operator checkout {operator}")
    require_pinned_checkout(operator)
    builds = {name: kustomize_build(operator, spec) for name, spec in SCENARIOS.items()}

    expected_dir, crd_dir = HERE / "expected", DEFAULT_CHART / "crds"
    expected_dir.mkdir(exist_ok=True)
    crd_dir.mkdir(parents=True, exist_ok=True)
    for name, text in builds.items():
        header = f"# Operator output for the {name} scenario, written by drift.py sync. Do not edit by hand.\n"
        (expected_dir / f"{name}.yaml").write_text(header + text, encoding="utf-8")

    crds = {}
    for part in split_documents(builds["default"]):
        doc = yaml.safe_load(part)
        if doc and doc["kind"] == "CustomResourceDefinition":
            crds[doc["metadata"]["name"]] = part
    for stale in crd_dir.glob("*.yaml"):
        if stale.stem not in crds:
            stale.unlink()
    for name, part in crds.items():
        (crd_dir / f"{name}.yaml").write_text(part, encoding="utf-8")
    print(f"wrote {len(builds)} scenarios and {len(crds)} CRDs from the operator build at {pinned_head()}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    commands = parser.add_subparsers(dest="command", required=True)
    sync = commands.add_parser("sync", help="rebuild expected/ and crds/ from an operator checkout")
    sync.add_argument("--operator", required=True, help="operator checkout at the commit in operator-ref")
    check = commands.add_parser("check", help="compare the chart with expected/")
    check.add_argument("--chart", default=str(DEFAULT_CHART), help="chart directory (default: gremlin-operator)")
    check.add_argument("--junit", help="write one test case per scenario to this file")
    args = parser.parse_args(argv)
    try:
        return cmd_sync(args) if args.command == "sync" else cmd_check(args)
    except DriftError as err:
        print(err, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
