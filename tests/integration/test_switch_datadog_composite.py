"""The Switch P0 alerts in Datadog: a silent ratio monitor and a silent volume monitor under one composite.

These run the real Datadog module and the real provider with OpenTofu against a local stand-in for the
Datadog API (see datadog_harness.py). What they cannot show is how Datadog itself evaluates a query:
the condition tests below evaluate the thresholds and operators read back out of the planned monitors,
using the semantics Datadog documents (a ratio of sums for as_count queries, and a composite that is
alert-worthy only when every member is).
"""

import itertools
import json
import os
from pathlib import Path
import operator
import re
import shutil
import tempfile
import unittest

import datadog_harness as harness

GOLDEN = Path(__file__).with_name("golden")
WEBHOOK = ["https://hooks.example.invalid/zenduty"]
EMAIL = "switch-verification-email-failing"
PROVISIONING = "switch-account-provisioning-failing"
OPERATORS = {"<": operator.lt, "<=": operator.le, ">": operator.gt, ">=": operator.ge}


def address(kind, alert):
    return f'datadog_monitor.{kind}["{alert}"]'


def threshold_of(query):
    """The operator and number a monitor query ends with, e.g. '... < 0.5' -> (lt, 0.5)."""
    operator_text, number = re.search(r"(<=|>=|<|>)\s*([0-9.]+)$", query).groups()
    return OPERATORS[operator_text], float(number)


class DatadogComposite(unittest.TestCase):
    """Shared scratch space: one provider download, one plan of the real rules."""

    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.scratch.cleanup)
        # The provider is a large download, so it is kept between runs unless the caller names a cache.
        cls.cache = Path(os.environ.get("TF_PLUGIN_CACHE_DIR") or Path(tempfile.gettempdir()) / "divyam-tf-plugin-cache")
        cls.cache.mkdir(parents=True, exist_ok=True)
        cls.mock = harness.MockDatadog()
        cls.addClassCleanup(cls.mock.close)
        module = harness.DatadogModule(cls.mock, Path(cls.scratch.name) / "plan", plugin_cache=cls.cache)
        module.init()
        cls.plan = module.plan(webhooks=WEBHOOK)
        cls.monitors = harness.planned_monitors(cls.plan)

    def _applied(self, rules_edit=None):
        """A fresh module and mock that the test may apply, destroy and edit."""
        mock = harness.MockDatadog()
        self.addCleanup(mock.close)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        module = harness.DatadogModule(mock, Path(tmp.name), plugin_cache=self.cache)
        if rules_edit:
            rules_edit(module.rules)
        module.init()
        return module, mock

    # --- the existing monitors must not move ------------------------------------------------------

    def test_every_existing_monitor_plans_exactly_as_before(self):
        existing = {a: m for a, m in self.monitors.items() if "switch-" not in a}
        expected = json.loads((GOLDEN / "existing_datadog_monitor_plan.json").read_text(encoding="utf-8"))
        changed = sorted(a for a in expected.keys() & existing.keys() if expected[a] != existing[a])
        self.assertEqual(
            (sorted(expected.keys() - existing.keys()), sorted(existing.keys() - expected.keys()), changed), ([], [], []),
            "Existing Datadog monitors no longer plan as tests/integration/golden/existing_datadog_monitor_plan.json "
            "records (removed, added, changed). They are addressed as datadog_monitor.alerts[...], so a change here would "
            "move or rewrite live monitors.")

    def test_a_floored_rule_adds_three_monitors_and_nothing_else_changes_shape(self):
        added = sorted(a for a in self.monitors if "switch-" in a)
        self.assertEqual(added, sorted(address(kind, alert) for alert in (EMAIL, PROVISIONING)
                                       for kind in ("composite", "floor_ratio", "floor_volume")))
        self.assertEqual(len(self.monitors), 17 + 6)

    # --- the members are silent, only the composite notifies ----------------------------------------

    def test_only_the_composite_carries_the_pager_handle_and_a_priority(self):
        for alert in (EMAIL, PROVISIONING):
            composite = self.monitors[address("composite", alert)]
            self.assertIn("@webhook-divyam-pager-0", composite["message"], alert)
            self.assertEqual(str(composite["priority"]), "1", alert)
            for kind in ("floor_ratio", "floor_volume"):
                member = self.monitors[address(kind, alert)]
                self.assertNotIn("@", member["message"], f"{alert} {kind} must never notify")
                self.assertIsNone(member["priority"], f"{alert} {kind}")
                self.assertEqual(member["renotify_interval"], 0, f"{alert} {kind} must not re-notify")
                self.assertFalse(member["renotify_statuses"], f"{alert} {kind}")
                self.assertFalse([t for t in member["tags"] if t.startswith("severity:")], f"{alert} {kind}")
                self.assertIn(f"composite_member:{alert}", member["tags"])

    def test_the_composite_keeps_the_alert_name_and_the_members_are_named_for_it(self):
        for alert in (EMAIL, PROVISIONING):
            self.assertEqual(self.monitors[address("composite", alert)]["name"], alert)
            self.assertEqual(self.monitors[address("floor_ratio", alert)]["name"], f"{alert}-ratio")
            self.assertEqual(self.monitors[address("floor_volume", alert)]["name"], f"{alert}-volume")
            self.assertEqual(self.monitors[address("composite", alert)]["type"], "composite")

    def test_missing_data_never_notifies_from_any_of_the_three(self):
        """Datadog needs the members and the composite to notify for a no-data alert, and none of them does."""
        for alert in (EMAIL, PROVISIONING):
            for kind in ("composite", "floor_ratio", "floor_volume"):
                monitor = self.monitors[address(kind, alert)]
                self.assertIs(monitor["notify_no_data"], False, f"{alert} {kind}")
                self.assertIsNone(monitor["no_data_timeframe"], f"{alert} {kind}")

    def test_the_members_do_not_wait_for_a_full_window_but_every_existing_monitor_still_does(self):
        """Datadog cancels an evaluation over an unfilled window and leaves the monitor in its previous state."""
        for alert in (EMAIL, PROVISIONING):
            for kind in ("floor_ratio", "floor_volume", "composite"):
                self.assertIs(self.monitors[address(kind, alert)]["require_full_window"], False, f"{alert} {kind}")
        existing = {a: m for a, m in self.monitors.items() if "switch-" not in a}
        self.assertEqual({m["require_full_window"] for m in existing.values()}, {True},
                         "the setting is changed for the new monitors only")

    def test_everything_floored_resolves_after_an_hour_without_data_and_nothing_else_does(self):
        for alert in (EMAIL, PROVISIONING):
            for kind in ("floor_ratio", "floor_volume", "composite"):
                self.assertEqual(str(self.monitors[address(kind, alert)]["timeout_h"]), "1", f"{alert} {kind}")
        existing = {a: m for a, m in self.monitors.items() if "switch-" not in a}
        self.assertEqual({m["timeout_h"] for m in existing.values()}, {None}, "no existing monitor gained an auto-resolve")

    def test_a_floored_rule_cannot_ask_to_notify_on_missing_data(self):
        def ask_for_no_data(rules):
            path = rules / "switch.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            data["rules"][0]["notification"] = {"notify_no_data": True}
            path.write_text(json.dumps(data), encoding="utf-8")

        module, _ = self._applied(ask_for_no_data)
        with self.assertRaises(AssertionError) as raised:
            module.plan(webhooks=WEBHOOK)
        self.assertIn("a composite can only alert on missing data if its members do too", str(raised.exception))

    # --- what the members query -------------------------------------------------------------------

    def test_the_members_use_the_same_windows_and_scope_as_the_prometheus_rules(self):
        expected = {
            EMAIL: ("sum(last_10m):", "switch_email_send.count", 10, "template:verification_code"),
            PROVISIONING: ("sum(last_15m):", "switch_provisioning.count", 5, None),
        }
        for alert, (window, metric, floor, tag) in expected.items():
            ratio = self.monitors[address("floor_ratio", alert)]["query"]
            volume = self.monitors[address("floor_volume", alert)]["query"]
            self.assertTrue(ratio.startswith(window), ratio)
            self.assertTrue(volume.startswith(window), volume)
            self.assertTrue(volume.endswith(f">= {floor}"), volume)
            self.assertEqual(volume.count(".as_count()"), 1, volume)
            self.assertNotIn("result:", volume, "the volume monitor counts every attempt, whatever its result")
            if tag:
                self.assertIn(tag, volume)
                self.assertEqual(ratio.count(tag), 2)
            self.assertIn(f"self_serve_server_preprod.{metric}", volume)

    # --- the conditions ----------------------------------------------------------------------------

    def _composite_fires(self, alert, success, failed, unknown=0):
        """Evaluate the planned members on one window's counts, as Datadog documents: a ratio of sums, then AND."""
        total = success + failed + unknown
        ratio_op, ratio_limit = threshold_of(self.monitors[address("floor_ratio", alert)]["query"])
        volume_op, volume_limit = threshold_of(self.monitors[address("floor_volume", alert)]["query"])
        ratio_alerts = total > 0 and ratio_op(success / total, ratio_limit)
        volume_alerts = volume_op(total, volume_limit)
        return ratio_alerts and volume_alerts

    def _prometheus_fires(self, floor, success, failed, unknown=0):
        total = success + failed + unknown
        return total >= floor and (failed + unknown) / total > 0.5

    def test_the_composite_agrees_with_the_prometheus_rule_on_every_window(self):
        """The same condition in both backends, floor and boundary included."""
        for success, failed, unknown in itertools.product(range(13), repeat=3):
            self.assertEqual(self._composite_fires(EMAIL, success, failed, unknown),
                             self._prometheus_fires(10, success, failed, unknown), (success, failed, unknown))
        for success, failed in itertools.product(range(11), repeat=2):
            self.assertEqual(self._composite_fires(PROVISIONING, success, failed),
                             self._prometheus_fires(5, success, failed), (success, failed))

    def test_low_traffic_never_pages_however_bad_the_ratio(self):
        self.assertFalse(self._composite_fires(EMAIL, success=0, failed=9), "nine attempts, all failed")
        self.assertFalse(self._composite_fires(EMAIL, success=0, failed=0, unknown=9), "nine attempts, all unknown")
        self.assertFalse(self._composite_fires(EMAIL, success=0, failed=1), "a single failed send")
        self.assertTrue(self._composite_fires(EMAIL, success=0, failed=10), "ten attempts, all failed")
        self.assertFalse(self._composite_fires(PROVISIONING, success=0, failed=4), "four attempts, all failed")
        self.assertTrue(self._composite_fires(PROVISIONING, success=0, failed=5), "five attempts, all failed")

    def test_the_boundaries_match_the_agreed_conditions(self):
        self.assertFalse(self._composite_fires(EMAIL, success=5, failed=3, unknown=2), "exactly half unconfirmed")
        self.assertTrue(self._composite_fires(EMAIL, success=4, failed=3, unknown=3), "more than half unconfirmed")
        self.assertTrue(self._composite_fires(EMAIL, success=0, failed=0, unknown=10), "unknown counts as unconfirmed")
        self.assertFalse(self._composite_fires(EMAIL, success=100, failed=1), "a healthy ratio with plenty of traffic")
        self.assertFalse(self._composite_fires(PROVISIONING, success=3, failed=3), "exactly half")

    def test_no_traffic_at_all_is_not_an_alert(self):
        self.assertFalse(self._composite_fires(EMAIL, 0, 0, 0))
        self.assertFalse(self._composite_fires(PROVISIONING, 0, 0))

    def test_the_alert_recovers_as_the_window_slides_past_the_failures(self):
        """Failures for twelve minutes, then healthy traffic: the composite must fire, and then clear."""
        window = 10
        failed = [3] * 12 + [0] * 28
        success = [1] * 12 + [10] * 28
        history = []
        for minute in range(len(failed)):
            lo = max(0, minute - window + 1)
            history.append(self._composite_fires(EMAIL, sum(success[lo:minute + 1]), sum(failed[lo:minute + 1])))
        self.assertTrue(any(history[:12]), "it must page while the failures last")
        self.assertFalse(history[0], "and not before enough attempts have accumulated")
        self.assertFalse(any(history[-5:]), "and it must clear once the window holds only healthy traffic")
        first_clear = next(i for i in range(12, len(history)) if not history[i])
        self.assertTrue(all(not state for state in history[first_clear:]), "and stay clear")

    # --- when the metrics stop after a P0 has fired -------------------------------------------------
    # A model of what Datadog documents, not Datadog: a composite is alert-worthy when its members are
    # (Alert, Warn and No Data all count as alert-worthy), AND gives the least severe member status, and
    # with the composite's no-data notification off a No Data result is replaced by the composite's last
    # known state. A triggered monitor is auto-resolved only when data is no longer being submitted.
    # The page's table has no row for two No Data members with the notification off, so that case is
    # taken to be last known state too, by analogy with the row that is there.

    SEVERITY = {"Ok": 1, "No Data": 2, "Warn": 3, "Alert": 4}
    ALERT_WORTHY = {"Alert", "Warn", "No Data"}

    def _composite_status(self, ratio, volume, last, notify_no_data=False):
        if ratio not in self.ALERT_WORTHY or volume not in self.ALERT_WORTHY:
            return "Ok"
        least = min((ratio, volume), key=self.SEVERITY.get)
        if least == "No Data" and not notify_no_data:
            return last
        return least

    def _stale_notifications(self, member_after_stop, timeout_h, hours=24, renotify=30):
        """Notifications sent after the metrics stop while the composite is still alerting, and when it clears."""
        composite, sent, cleared_at = "Alert", 0, None
        for minute in range(1, hours * 60 + 1):
            no_data_hours = minute / 60
            member = "Ok" if timeout_h is not None and no_data_hours >= timeout_h else member_after_stop
            composite = self._composite_status(member, member, composite)
            if composite != "Alert":
                cleared_at = minute
                break
            if minute % renotify == 0:
                sent += 1
        return sent, cleared_at

    def test_the_documented_composite_table_cells_this_design_relies_on(self):
        self.assertEqual(self._composite_status("Alert", "Ok", "Alert"), "Ok", "alert AND ok is ok")
        self.assertEqual(self._composite_status("No Data", "Ok", "Alert"), "Ok", "a member that is ok clears the composite")
        self.assertEqual(self._composite_status("Alert", "Alert", "Ok"), "Alert")
        self.assertEqual(self._composite_status("No Data", "Warn", "Alert"), "Alert", "last known state when no-data notify is off")
        self.assertEqual(self._composite_status("No Data", "Warn", "Alert", notify_no_data=True), "No Data")

    def test_without_auto_resolve_a_composite_that_was_alerting_alerts_and_renotifies_for_ever(self):
        """The problem the timeout solves: whichever way the members look once data stops, the composite is stuck."""
        for member_after_stop in ("Alert", "No Data"):
            sent, cleared = self._stale_notifications(member_after_stop, timeout_h=None)
            self.assertIsNone(cleared, member_after_stop)
            self.assertGreater(sent, 40, f"{member_after_stop}: a day of stale pages, one every half hour")

    def test_with_the_configured_auto_resolve_the_stale_alert_clears_and_pages_at_most_twice(self):
        for alert in (EMAIL, PROVISIONING):
            timeout_h = int(str(self.monitors[address("floor_ratio", alert)]["timeout_h"]))
            renotify = int(self.monitors[address("composite", alert)]["renotify_interval"])
            for member_after_stop in ("Alert", "No Data"):
                sent, cleared = self._stale_notifications(member_after_stop, timeout_h, renotify=renotify)
                self.assertIsNotNone(cleared, f"{alert} {member_after_stop}: it must clear")
                self.assertLessEqual(cleared, timeout_h * 60 + 1, alert)
                self.assertLessEqual(sent, 2, f"{alert} {member_after_stop}: at most {sent} stale notifications")

    def test_auto_resolve_never_clears_an_outage_that_is_still_reporting(self):
        """Datadog only auto-resolves when data is no longer being submitted, so a live failure keeps alerting."""
        composite = "Alert"
        for _minute in range(1, 24 * 60):
            composite = self._composite_status("Alert", "Alert", composite)  # data still arrives, members still alert
        self.assertEqual(composite, "Alert")

    # --- Terraform: creating and removing -----------------------------------------------------------

    def _ok(self, result):
        """Fail with what tofu said, so an intermittent apply error can be diagnosed from the report."""
        self.assertEqual(result.returncode, 0, (result.stdout + result.stderr)[-2500:])

    def _ids(self, mock):
        return {m["name"]: i for i, m in mock.monitors.items()}

    def test_members_are_created_before_the_composite_that_refers_to_them(self):
        module, mock = self._applied()
        result = module.apply()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        created = mock.order("POST")
        ids = self._ids(mock)
        for alert in (EMAIL, PROVISIONING):
            self.assertLess(created.index(f"{alert}-ratio"), created.index(alert), alert)
            self.assertLess(created.index(f"{alert}-volume"), created.index(alert), alert)
            composite = mock.monitors[ids[alert]]
            self.assertEqual(composite["type"], "composite")
            self.assertEqual(composite["query"], f"{ids[f'{alert}-ratio']} && {ids[f'{alert}-volume']}")
        self.assertEqual(len(mock.monitors), 23)
        self.assertEqual(set(module.outputs()["monitor_ids"]["value"]) & {EMAIL, PROVISIONING}, {EMAIL, PROVISIONING},
                         "a floored rule is reported under its alert name, as a plain one is")

    def test_the_requests_sent_to_datadog_carry_the_window_and_auto_resolve_options(self):
        """What is sent, not just what is planned: the options Datadog would actually receive."""
        module, mock = self._applied()
        self._ok(module.apply())
        sent = {body["name"]: body for _, body in mock.calls("POST")}
        for alert in (EMAIL, PROVISIONING):
            for name in (alert, f"{alert}-ratio", f"{alert}-volume"):
                options = sent[name]["options"]
                self.assertEqual(options["timeout_h"], 1, name)
                self.assertIs(options["require_full_window"], False, name)
                self.assertIs(options["notify_no_data"], False, name)
        existing = [body for name, body in sent.items() if not name.startswith("switch-")]
        self.assertEqual(len(existing), 17)
        self.assertTrue(all(body["options"].get("require_full_window") is True for body in existing))
        self.assertTrue(all(not body["options"].get("timeout_h") for body in existing),
                        "no existing monitor is sent an auto-resolve")

    def test_destroy_deletes_the_composite_before_its_members(self):
        module, mock = self._applied()
        self._ok(module.apply())
        ids = self._ids(mock)
        result = module.destroy()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        deleted = mock.order("DELETE")
        for alert in (EMAIL, PROVISIONING):
            self.assertLess(deleted.index(ids[alert]), deleted.index(ids[f"{alert}-ratio"]), alert)
            self.assertLess(deleted.index(ids[alert]), deleted.index(ids[f"{alert}-volume"]), alert)
        self.assertEqual(mock.monitors, {})

    def _untouched_existing(self, mock, ids_before):
        touched = {int(path.rsplit("/", 1)[1]) for method, path, _ in mock.requests
                   if method in ("PUT", "DELETE") and path.startswith("/api/v1/monitor/") and not path.endswith("/validate")}
        existing_ids = {i for name, i in ids_before.items() if not name.startswith("switch-")}
        self.assertEqual(touched & existing_ids, set(), "an existing monitor was updated or deleted")

    def test_removing_the_floor_from_a_rule_swaps_the_composite_for_a_plain_monitor(self):
        module, mock = self._applied()
        self._ok(module.apply())
        ids = self._ids(mock)

        path = module.rules / "switch.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        del data["rules"][0]["datadog"]["floor"]
        path.write_text(json.dumps(data), encoding="utf-8")
        result = module.apply()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

        names = sorted(m["name"] for m in mock.monitors.values())
        self.assertEqual(names.count(EMAIL), 1, "exactly one monitor under the alert name")
        self.assertNotIn(f"{EMAIL}-ratio", names)
        self.assertNotIn(f"{EMAIL}-volume", names)
        self.assertEqual([m["type"] for m in mock.monitors.values() if m["name"] == EMAIL], ["metric alert"])
        self.assertIn(f"{PROVISIONING}-ratio", names, "the other rule is untouched")
        deleted = mock.order("DELETE")
        self.assertLess(deleted.index(ids[EMAIL]), deleted.index(ids[f"{EMAIL}-ratio"]))
        self._untouched_existing(mock, ids)

    def test_removing_a_rule_deletes_its_composite_first_and_touches_nothing_else(self):
        module, mock = self._applied()
        self._ok(module.apply())
        ids = self._ids(mock)
        (module.rules / "switch.json").unlink()
        result = module.apply()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(mock.monitors), 17)
        self.assertFalse([m for m in mock.monitors.values() if m["name"].startswith("switch-")])
        deleted = mock.order("DELETE")
        for alert in (EMAIL, PROVISIONING):
            self.assertLess(deleted.index(ids[alert]), deleted.index(ids[f"{alert}-ratio"]), alert)
        self._untouched_existing(mock, ids)

    def test_disabling_the_module_removes_all_three_monitors_without_a_conflict(self):
        module, mock = self._applied()
        self._ok(module.apply())
        result = module.apply(enabled="false")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(mock.monitors, {})

    def test_the_stand_in_really_refuses_the_wrong_order(self):
        """Without this, the ordering tests above could pass against an API that accepts anything."""
        mock = harness.MockDatadog()
        self.addCleanup(mock.close)
        status, _ = mock.route("POST", "/api/v1/monitor", {"name": "c", "type": "composite", "query": "1 && 2"})
        self.assertEqual(status, 400, "a composite over monitors that do not exist must be refused")
        _, first = mock.route("POST", "/api/v1/monitor", {"name": "a", "type": "metric alert", "query": "q"})
        _, second = mock.route("POST", "/api/v1/monitor", {"name": "b", "type": "metric alert", "query": "q"})
        _, composite = mock.route("POST", "/api/v1/monitor",
                                  {"name": "c", "type": "composite", "query": f"{first['id']} && {second['id']}"})
        status, _ = mock.route("DELETE", f"/api/v1/monitor/{first['id']}", {})
        self.assertEqual(status, 409, "a member must not be deletable while a composite refers to it")
        self.assertEqual(mock.route("DELETE", f"/api/v1/monitor/{composite['id']}", {})[0], 200)
        self.assertEqual(mock.route("DELETE", f"/api/v1/monitor/{first['id']}", {})[0], 200)


if __name__ == "__main__":
    unittest.main()
