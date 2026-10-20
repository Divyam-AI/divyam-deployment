"""Render the alert rules with OpenTofu, replay Switch's counters through promtool, and pin the existing alerts."""

import itertools
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
ALERTS = ROOT / "iac/2-app/2-alerts/common"
GOLDEN = Path(__file__).with_name("golden")
ENV = "preprod"
CLUSTER = "test-cluster"
NAMESPACE = f"self-serve-{ENV}-ns"
EMAIL = "switch-verification-email-failing"
PROVISIONING = "switch-account-provisioning-failing"
SWITCH = (EMAIL, PROVISIONING)
SENDS = "switch_email_send_total"
SETUPS = "switch_provisioning_total"


def email(result, values, template="verification_code", namespace=NAMESPACE):
    labels = f'namespace="{namespace}",template="{template}",result="{result}"'
    return {"series": f"{SENDS}{{{labels}}}", "values": values}


def setup(result, values, namespace=NAMESPACE):
    return {"series": f'{SETUPS}{{namespace="{namespace}",result="{result}"}}', "values": values}


def canonical(value):
    """The form the golden files are written in, so a comparison is exact and a diff is readable."""
    return json.loads(json.dumps(value, sort_keys=True))


class SwitchAlertRuleTests(unittest.TestCase):
    """Exercise the real renderer and the real PromQL engine, with no cluster or cloud account."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.tmp.cleanup)
        folder = Path(cls.tmp.name) / "render"
        folder.mkdir()
        for source in (ALERTS / "render").glob("*.tf"):
            shutil.copyfile(source, folder / source.name)
        tofu = os.environ.get("TOFU_BIN", "tofu")
        variables = [
            "-var", f"rules_folder={(ALERTS / 'rules').as_posix()}",
            "-var", f"metric_map_file={(ALERTS / 'rules/metric_map.json').as_posix()}",
            "-var", f"cluster_name={CLUSTER}", "-var", f"env={ENV}",
        ]
        for command in (["init", "-backend=false", "-input=false"], ["apply", "-auto-approve", "-input=false", *variables]):
            result = subprocess.run([tofu, *command, "-no-color"], cwd=folder, capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr

        def output(name):
            result = subprocess.run([tofu, "output", "-json", name], cwd=folder, capture_output=True, text=True)
            assert result.returncode == 0, result.stderr
            return json.loads(result.stdout)

        cls.rules = {rule["alert"]: rule for rule in output("prometheus_rules")}
        cls.datadog = output("datadog_monitors")

    # --- the existing alerts must not move ---------------------------------------------------

    def _compare_with_golden(self, name, rendered):
        path = GOLDEN / name
        if os.environ.get("UPDATE_GOLDEN"):
            path.write_text(json.dumps(rendered, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        expected = {item["alert"]: item for item in json.loads(path.read_text(encoding="utf-8"))} \
            if isinstance(rendered, list) else json.loads(path.read_text(encoding="utf-8"))
        actual = {item["alert"]: item for item in canonical(rendered)} if isinstance(rendered, list) else canonical(rendered)
        changed = sorted(alert for alert in expected.keys() & actual.keys() if expected[alert] != actual[alert])
        self.assertEqual(
            (sorted(expected.keys() - actual.keys()), sorted(actual.keys() - expected.keys()), changed), ([], [], []),
            f"Existing alerts no longer render as tests/integration/golden/{name} records "
            "(removed, added, changed). If the change is deliberate, regenerate it with UPDATE_GOLDEN=1 and review the diff.",
        )

    def test_every_existing_prometheus_rule_renders_exactly_as_before(self):
        existing = sorted((rule for name, rule in self.rules.items() if name not in SWITCH), key=lambda rule: rule["alert"])
        self._compare_with_golden("existing_prometheus_rules.json", existing)

    def test_every_existing_datadog_monitor_renders_exactly_as_before(self):
        existing = {name: monitor for name, monitor in self.datadog.items() if name not in SWITCH}
        self._compare_with_golden("existing_datadog_monitors.json", existing)

    def test_the_snapshot_itself_holds_no_switch_alert(self):
        """A snapshot that quietly absorbed the new rules would stop protecting the old ones."""
        for name in ("existing_prometheus_rules.json", "existing_datadog_monitors.json"):
            self.assertNotIn("switch-", (GOLDEN / name).read_text(encoding="utf-8"), name)

    # --- how the two new alerts render -------------------------------------------------------

    def test_both_alerts_render_as_critical_with_the_agreed_timing(self):
        for name in SWITCH:
            rule = self.rules[name]
            self.assertEqual(rule["severity"], "CRITICAL", name)
            self.assertEqual(rule["for"], "2m", name)
            self.assertIsNone(rule["runbook_url"], name)
            self.assertIsNone(rule["auto_resolve"], name)
            self.assertNotIn("{{", rule["expr"], f"{name} still has an unsubstituted placeholder")

    def test_the_prometheus_queries_are_scoped_to_the_environments_namespace(self):
        for name in SWITCH:
            expr = self.rules[name]["expr"]
            self.assertEqual(expr.count("namespace="), expr.count("switch_"), name)
            self.assertIn(f'namespace="{NAMESPACE}"', expr)

    def test_both_alerts_have_a_datadog_monitor_that_does_not_page_on_missing_data(self):
        for name in SWITCH:
            monitor = self.datadog[name]
            self.assertEqual(monitor["severity"], "CRITICAL", name)
            self.assertIs(monitor["notification"]["notify_no_data"], False, f"{name}: zero signups, or no Switch at all, is not an outage")
            self.assertNotIn("{{", monitor["query"], f"{name} still has an unsubstituted placeholder")

    def test_the_datadog_queries_use_the_names_the_openmetrics_check_produces(self):
        """The chart prefixes <app>-<env>, the check drops _total and adds .count, and Datadog reads - as _."""
        expected = {
            EMAIL: ("sum(last_10m):", "self_serve_server_preprod.switch_email_send.count", ["template:verification_code"]),
            PROVISIONING: ("sum(last_15m):", "self_serve_server_preprod.switch_provisioning.count", []),
        }
        for name, (aggregation, metric, tags) in expected.items():
            query = self.datadog[name]["query"]
            self.assertTrue(query.startswith(aggregation), f"{name}: {query}")
            self.assertEqual(query.count(f"sum:{metric}{{"), 2, f"{name}: one numerator and one denominator")
            self.assertEqual(query.count(".as_count()"), 2, f"{name}: as_count on every term is what makes it a ratio of sums")
            self.assertEqual(query.count(f"kube_cluster_name:{CLUSTER}"), 2, name)
            self.assertEqual(query.count(f"kube_namespace:{NAMESPACE}"), 2, name)
            self.assertEqual(query.count("result:success"), 1, f"{name}: only the numerator is limited to success")
            for tag in tags:
                self.assertEqual(query.count(tag), 2, f"{name}: {tag} must scope both terms")
            self.assertTrue(query.endswith("< 0.5"), f"{name}: {query}")

    def test_the_datadog_and_prometheus_conditions_agree(self):
        """(failed + unknown) / total > 0.5 and success / total < 0.5 are one condition, boundary included."""
        for success, failed, unknown in itertools.product(range(8), repeat=3):
            total = success + failed + unknown
            if total == 0:
                continue
            prometheus = (failed + unknown) / total > 0.5
            datadog = success / total < 0.5
            self.assertEqual(prometheus, datadog, (success, failed, unknown))

    # --- simulated conditions ----------------------------------------------------------------

    def _promtool(self, name, scenarios):
        """Run scenarios [(label, input_series, {eval_time: should_fire})] against one rendered rule."""
        rule = self.rules[name]
        labels = {"severity": rule["severity"], **rule["labels"]}
        folder = Path(self.tmp.name) / name
        folder.mkdir()
        (folder / "rules.yml").write_text(yaml.safe_dump({"groups": [{"name": "switch", "interval": "1m", "rules": [
            {"alert": name, "expr": rule["expr"], "for": rule["for"], "labels": labels}]}]}))
        tests = []
        for label, series, expectations in scenarios:
            tests.append({"interval": "1m", "name": label, "input_series": series, "alert_rule_test": [
                {"eval_time": at, "alertname": name, "exp_alerts": [{"exp_labels": labels}] if fires else []}
                for at, fires in expectations.items()]})
        (folder / "tests.yml").write_text(yaml.safe_dump({"rule_files": ["rules.yml"], "evaluation_interval": "1m", "tests": tests}))
        promtool = os.environ.get("PROMTOOL_BIN", "promtool")
        for command in (["check", "rules", "rules.yml"], ["test", "rules", "tests.yml"]):
            result = subprocess.run([promtool, *command], cwd=folder, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_email_alert_conditions(self):
        self._promtool(EMAIL, [
            ("a majority of sends failing pages after the for-duration, not before",
             [email("failed", "0+3x30"), email("success", "0+1x30")], {"1m": False, "25m": True}),
            ("unknown sends count as failures, because an outage that hangs connections ends there",
             [email("unknown", "0+3x30"), email("success", "0+1x30")], {"25m": True}),
            ("failed plus unknown together cross the line when neither does alone",
             [email("failed", "0+1x30"), email("unknown", "0+1x30"), email("success", "0+1x30")], {"25m": True}),
            ("a healthy ratio stays quiet",
             [email("failed", "0+1x30"), email("success", "0+5x30")], {"25m": False}),
            ("exactly half is not above half",
             [email("failed", "0+1x30"), email("success", "0+1x30")], {"25m": False}),
            ("every send failing but fewer than ten attempts stays quiet",
             [email("failed", "0 0 0 1 1 1 2 2 2 3 3 3 4 4 4 5 5 5 6 6 6 7 7 7 8 8 8")], {"12m": False, "25m": False}),
            ("account alert emails never count",
             [email("failed", "0+10x30", template="account_alert"), email("success", "0+2x30")], {"25m": False}),
            ("another environment's namespace never counts",
             [email("failed", "0+10x30", namespace="self-serve-prod-ns")], {"25m": False}),
            ("no traffic at all produces no alert", [], {"25m": False}),
            ("a counter reset does not hide continuing failures",
             [email("failed", "0+4x5 0+4x5 0+4x5 0+4x5 0+4x5"), email("success", "0+1x30")], {"25m": True}),
            ("the alert resolves once failures stop",
             [email("failed", "0+3x12 36x40"), email("success", "0+1x12 12+10x40")], {"12m": True, "40m": False}),
        ])

    def test_provisioning_alert_conditions(self):
        self._promtool(PROVISIONING, [
            ("a majority of setups failing pages after the for-duration, not before",
             [setup("failed", "0+2x40"), setup("success", "0+1x40")], {"1m": False, "30m": True}),
            ("a healthy ratio stays quiet",
             [setup("failed", "0+1x40"), setup("success", "0+9x40")], {"30m": False}),
            ("exactly half is not above half",
             [setup("failed", "0+1x40"), setup("success", "0+1x40")], {"30m": False}),
            ("every setup failing but fewer than five attempts stays quiet",
             [setup("failed", "0 0 0 0 0 1 1 1 1 1 2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 5 5 5 5 5 6 6 6")], {"20m": False, "30m": False}),
            ("another environment's namespace never counts",
             [setup("failed", "0+5x40", namespace="self-serve-prod-ns")], {"30m": False}),
            ("no traffic at all produces no alert", [], {"30m": False}),
            ("a counter reset does not hide continuing failures",
             [setup("failed", "0+3x6 0+3x6 0+3x6 0+3x6 0+3x6 0+3x6"), setup("success", "0+1x40")], {"30m": True}),
            ("the alert resolves once failures stop",
             [setup("failed", "0+2x15 30x50"), setup("success", "0+1x15 15+5x50")], {"15m": True, "60m": False}),
        ])


if __name__ == "__main__":
    unittest.main()
