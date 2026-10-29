import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import drift  # noqa: E402


def deployment(name="d", namespace="ns", labels=None, annotations=None, args=None, image="x"):
    return {"kind": "Deployment", "metadata": {"name": name, "namespace": namespace, "labels": {"a": "b"}},
            "spec": {"template": {"metadata": {"labels": labels or {}, "annotations": annotations or {}},
                                  "spec": {"containers": [{"name": "manager", "image": image, "args": args or [],
                                                           "ports": []}]}}}}


def service(selector, name="s", namespace="ns"):
    return {"kind": "Service", "metadata": {"name": name, "namespace": namespace}, "spec": {"selector": selector}}


def network_policy(pod_selector, name="np", namespace="ns"):
    return {"kind": "NetworkPolicy", "metadata": {"name": name, "namespace": namespace},
            "spec": {"podSelector": pod_selector}}


class CompareTest(unittest.TestCase):
    def test_ignores_image_metadata_labels_arg_order_and_empty_collections(self):
        chart = deployment(args=["--b", "--a"], image="chart:1")
        operator = deployment(args=["--a", "--b"], image="operator:2")
        operator["metadata"]["labels"] = {"c": "d"}
        operator["spec"]["template"]["spec"]["volumes"] = []
        self.assertEqual(drift.compare("s", [chart], [operator]), [])

    def test_reports_object_and_field_for_changed_arg(self):
        lines = drift.compare("s", [deployment(args=["--x=1"])], [deployment(args=["--x=2"])])
        self.assertEqual(lines, ["s Deployment ns/d spec.template.spec.containers[0].args[0]: chart=--x=1 operator=--x=2"])

    def test_pod_template_labels_need_operator_keys_but_allow_extra_chart_keys(self):
        operator = deployment(labels={"app": "x"}, annotations={"k": "v"})
        self.assertEqual(drift.compare("s", [deployment(labels={"app": "x", "extra": "y"},
                                                        annotations={"k": "v", "other": "o"})], [operator]), [])
        lines = drift.compare("s", [deployment(labels={"app": "y"})], [operator])
        self.assertEqual(lines, ["s Deployment ns/d spec.template.metadata.labels.app: chart=y operator=x",
                                 "s Deployment ns/d spec.template.metadata.annotations.k: chart=None operator=v"])

    def test_reports_missing_and_extra_objects_and_skips_the_operator_namespace(self):
        operator_namespace = {"kind": "Namespace", "metadata": {"name": drift.OPERATOR_NAMESPACE}}
        lines = drift.compare("s", [deployment(name="only-chart")], [deployment(name="only-op"), operator_namespace])
        self.assertEqual(lines, ["s Deployment ns/only-chart: only in the chart",
                                 "s Deployment ns/only-op: only in the operator's output"])

    def test_lists_of_different_length_are_reported_whole_at_the_list_path(self):
        chart = {"kind": "Role", "metadata": {"name": "r"}, "rules": [{"verbs": ["get"]}]}
        operator = {"kind": "Role", "metadata": {"name": "r"}, "rules": [{"verbs": ["get"]}, {"verbs": ["list"]}]}
        lines = drift.compare("s", [chart], [operator])
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith("s Role /r rules: chart="))

    def test_long_values_are_truncated(self):
        self.assertTrue(drift.show("x" * 1000).endswith("..."))
        self.assertEqual(drift.show("short"), "short")


class SelectorGuardTest(unittest.TestCase):
    def setUp(self):
        self.pod = deployment(labels={"name": "n", "component": "c"})

    def test_contained_selectors_pass(self):
        docs = [self.pod, service({"name": "n"}), network_policy({"matchLabels": {"component": "c"}})]
        self.assertEqual(drift.selector_guard("s", docs), [])

    def test_reports_selector_no_pod_satisfies(self):
        lines = drift.selector_guard("s", [self.pod, service({"component": "other"})])
        self.assertEqual(lines, ["s Service ns/s spec.selector: matches no Deployment pod"])

    def test_pod_in_another_namespace_does_not_count(self):
        lines = drift.selector_guard("s", [self.pod, service({"name": "n"}, namespace="elsewhere")])
        self.assertEqual(len(lines), 1)

    def test_empty_and_match_expressions_selectors_are_reported(self):
        docs = [self.pod, service({}), network_policy({}),
                network_policy({"matchExpressions": [{"key": "name", "operator": "Exists"}]}, name="np2")]
        self.assertEqual(len(drift.selector_guard("s", docs)), 3)


class ValuesShapeTest(unittest.TestCase):
    def test_finds_fragment_keys_at_any_depth_and_ignores_security_context(self):
        values = {"reconciler": {"extraVolumes": [], "securityContext": {}}, "initContainers": [],
                  "credentialManager": {"nested": {"Sidecars": []}}, "extraVolumeMounts": []}
        self.assertEqual(sorted(drift.fragment_keys(values)),
                         ["credentialManager.nested.Sidecars", "extraVolumeMounts", "initContainers",
                          "reconciler.extraVolumes"])

    def test_clean_values_report_nothing(self):
        self.assertEqual(drift.fragment_keys({"reconciler": {"extraEnv": [], "resources": {}}}), [])


class SyncHelpersTest(unittest.TestCase):
    def test_split_documents_drops_empty_parts(self):
        self.assertEqual(drift.split_documents("a: 1\n---\nb: 2\n---\n"), ["a: 1\n", "b: 2\n"])

    def test_every_scenario_has_values_and_the_pin_is_a_full_hash(self):
        for name in drift.SCENARIOS:
            self.assertTrue((drift.HERE / "values" / f"{name}.yaml").is_file(), name)
        self.assertRegex(drift.pinned_head(), r"^[0-9a-f]{40}$")


if __name__ == "__main__":
    unittest.main()
