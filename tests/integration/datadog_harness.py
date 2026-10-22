"""Run the real Datadog alerts module with OpenTofu against a local stand-in for the Datadog API.

The stand-in enforces the two rules about composite monitors that decide whether the Terraform
ordering is right: a composite can only be created from monitors that already exist, and a monitor a
composite refers to cannot be deleted while the composite exists. Nothing here talks to Datadog.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[2]
ALERTS = ROOT / "iac/2-app/2-alerts"
PROVIDER_LINE = 'api_url = "https://api.${var.datadog_site}/"'

# What the module sets on every monitor itself, so a comparison does not depend on provider defaults.
MONITOR_FIELDS = (
    "name", "type", "query", "message", "priority", "tags", "include_tags", "notify_no_data",
    "no_data_timeframe", "require_full_window", "renotify_interval", "renotify_statuses", "monitor_thresholds",
    "timeout_h",
)


class MockDatadog:
    """A small, honest-enough Datadog v1 monitor API that records every call it receives."""

    def __init__(self):
        self.monitors = {}
        self.requests = []
        self._next_id = 5000
        self._lock = threading.Lock()
        mock = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def _send(self, status, body):
                data = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def _body(self):
                length = int(self.headers.get("Content-Length") or 0)
                return json.loads(self.rfile.read(length) or b"{}")

            def _handle(self, method):
                path = self.path.split("?")[0]
                body = self._body() if method in ("POST", "PUT") else {}
                with mock._lock:
                    mock.requests.append((method, path, body))
                    status, payload = mock.route(method, path, body)
                self._send(status, payload)

            def do_GET(self):
                self._handle("GET")

            def do_POST(self):
                self._handle("POST")

            def do_PUT(self):
                self._handle("PUT")

            def do_DELETE(self):
                self._handle("DELETE")

        class Server(ThreadingHTTPServer):
            # Terraform opens many connections at once. The default backlog of 5 makes a burst of them fail
            # with "connection refused", which looks like a Datadog error and is not one.
            request_queue_size = 256
            daemon_threads = True

        self.server = Server(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}/"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()

    @staticmethod
    def _referenced(monitor):
        return [int(i) for i in re.findall(r"\d+", monitor["query"])] if monitor.get("type") == "composite" else []

    def route(self, method, path, body):
        if method == "GET" and path == "/api/v1/validate":
            return 200, {"valid": True}
        if method == "POST" and (path == "/api/v1/monitor/validate" or re.fullmatch(r"/api/v1/monitor/\d+/validate", path)):
            return 200, {}
        match = re.fullmatch(r"/api/v1/monitor/(\d+)", path)
        if method == "POST" and path == "/api/v1/monitor":
            for ref in self._referenced(body):
                if ref not in self.monitors:
                    return 400, {"errors": [f"Monitor {ref} referenced by the composite does not exist"]}
            self._next_id += 1
            monitor = {**body, "id": self._next_id, "org_id": 1, "overall_state": "No Data", "multi": False,
                       "created": "2026-01-01T00:00:00+00:00", "modified": "2026-01-01T00:00:00+00:00",
                       "creator": {"email": "mock@example.invalid", "handle": "mock@example.invalid", "name": "mock"}}
            self.monitors[self._next_id] = monitor
            return 200, monitor
        if match:
            monitor_id = int(match.group(1))
            if monitor_id not in self.monitors:
                return 404, {"errors": ["Monitor not found"]}
            if method == "GET":
                return 200, self.monitors[monitor_id]
            if method == "PUT":
                self.monitors[monitor_id] = {**self.monitors[monitor_id], **body, "id": monitor_id}
                return 200, self.monitors[monitor_id]
            if method == "DELETE":
                for other in self.monitors.values():
                    if monitor_id in self._referenced(other):
                        return 409, {"errors": [f"Monitor {monitor_id} is used by composite monitor {other['id']}"]}
                del self.monitors[monitor_id]
                return 200, {"deleted_monitor_id": monitor_id}
        return 404, {"errors": [f"unhandled {method} {path}"]}

    def calls(self, method):
        return [(path, body) for m, path, body in self.requests if m == method and path.startswith("/api/v1/monitor")
                and not path.endswith("/validate")]

    def order(self, method):
        """Names (or ids, for a delete) of monitors in the order the API saw `method` calls."""
        out = []
        for path, body in self.calls(method):
            out.append(body.get("name") if method == "POST" else int(path.rsplit("/", 1)[1]))
        return out


class DatadogModule:
    """A scratch copy of the real module, its renderer and a rules folder, wired to a MockDatadog."""

    def __init__(self, mock, root_dir, rules_dir=None, source=None, plugin_cache=None):
        """`source` is a directory laid out like iac/2-app/2-alerts (the repo by default)."""
        source = Path(source or ALERTS)
        self.work = Path(root_dir)
        self.mock = mock
        for part in ("datadog", "common/render"):
            target = self.work / part
            target.mkdir(parents=True, exist_ok=True)
            for tf in (source / part).glob("*.tf"):
                shutil.copyfile(tf, target / tf.name)
        main = self.work / "datadog/main.tf"
        text = main.read_text(encoding="utf-8")
        assert PROVIDER_LINE in text, "the provider line changed, so the stand-in cannot be wired in"
        main.write_text(text.replace(PROVIDER_LINE, f'api_url = "{mock.url}"'), encoding="utf-8", newline="\n")
        self.rules = self.work / "common/rules"
        shutil.copytree(rules_dir or source / "common/rules", self.rules)
        self.tofu = os.environ.get("TOFU_BIN", "tofu")
        self.env = {**os.environ}
        if plugin_cache and not os.environ.get("TOFU_PLUGIN_DIR"):
            # An offline plugin directory and a plugin cache must not be the same folder, so offline wins.
            self.env["TF_PLUGIN_CACHE_DIR"] = str(plugin_cache)
        self.module = self.work / "datadog"

    def _run(self, *args):
        result = subprocess.run([self.tofu, *args, "-no-color"], cwd=self.module, env=self.env, capture_output=True, text=True)
        return result

    def _variables(self, webhooks, extra):
        values = {
            "datadog_site": "unused.invalid", "datadog_api_key": "key", "datadog_app_key": "app",
            "env": "preprod", "cluster_name": "test-cluster", "webhook_urls": json.dumps(webhooks),
            "rules_folder": self.rules.as_posix(), "metric_map_file": (self.rules / "metric_map.json").as_posix(),
            **extra,
        }
        return [arg for k, v in values.items() for arg in ("-var", f"{k}={v}")]

    def init(self):
        # TOFU_PLUGIN_DIR installs the provider from a local folder, so a run needs no registry access.
        offline = ["-plugin-dir", os.environ["TOFU_PLUGIN_DIR"]] if os.environ.get("TOFU_PLUGIN_DIR") else []
        result = self._run("init", "-backend=false", "-input=false", *offline)
        assert result.returncode == 0, result.stdout + result.stderr

    def plan(self, webhooks=(), **extra):
        plan = self.work / "plan.bin"
        result = self._run("plan", "-input=false", "-out", str(plan), *self._variables(list(webhooks), extra))
        assert result.returncode == 0, result.stdout + result.stderr
        shown = subprocess.run([self.tofu, "show", "-json", str(plan)], cwd=self.module, env=self.env, capture_output=True, text=True)
        assert shown.returncode == 0, shown.stderr
        return json.loads(shown.stdout)

    def apply(self, webhooks=(), **extra):
        result = self._run("apply", "-auto-approve", "-input=false", *self._variables(list(webhooks), extra))
        return result

    def destroy(self, webhooks=(), **extra):
        return self._run("destroy", "-auto-approve", "-input=false", *self._variables(list(webhooks), extra))

    def outputs(self):
        result = subprocess.run([self.tofu, "output", "-json"], cwd=self.module, env=self.env, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout)


def planned_monitors(plan):
    """address -> the fields the module sets, for every datadog_monitor the plan would create."""
    out = {}
    for change in plan["resource_changes"]:
        if change["type"] == "datadog_monitor":
            after = change["change"]["after"] or {}
            out[change["address"]] = {field: after.get(field) for field in MONITOR_FIELDS}
    return out


def new_scratch():
    return tempfile.TemporaryDirectory()
