"""Evaluate self-serve Helmfile membership and cloud identity definitions without deployment."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]


class SelfServeDeploymentTests(unittest.TestCase):
    """Exercise the actual Helmfile and OpenTofu evaluators with isolated input files."""

    def test_helmfile_keeps_self_serve_in_its_namespace_and_stack(self):
        """Self-serve selection must exclude Router workloads and preserve explicit ingress disablement."""
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            fixtures = {
                "provider.yaml": {"environment": "preprod", "stack": "self-serve", "deployment_mode": "managed", "clusterDomain": "svc.cluster.local",
                    "platform": {"provider": "GCP", "gcp": {"secretsProjectId": "test-project"}},
                    "imagePullSecretConfig": {"enabled": False}, "ingress": {"deploy": True},
                    "secrets": {"provider": "OPENBAO", "openbao": {"addr": "http://global"}}},
                "artifacts.yaml": {"chartBasePath": str(ROOT.parent / "divyam-helm-charts/charts"),
                    "self-serve-server": {"values": {}}, "self-serve-ui": {"values": {}},
                    "self-serve-ingress": {"values": {}}, "divyam-router-controller": {"values": {}},
                    "mysql": {"enabled": False, "values": {}}},
                "resources.yaml": {"settings": {}, "charts": {"self-serve-ingress": {"values": {"ingress": {"deploy": False}}},
                    "self-serve-server": {"values": {"secrets": {"provider": "GCP", "existingSecret": "runtime"}}}}},
            }
            for filename, content in fixtures.items():
                (folder / filename).write_text(yaml.safe_dump(content))
            env = {**os.environ, "HELMFILE_VALUES_DIR": directory}
            env.pop("ARTIFACTS_CHANNEL", None)
            env.pop("ARTIFACTS_VERSION", None)
            result = subprocess.run([
                os.environ.get("HELMFILE_BIN", "helmfile"), "--helm-binary", os.environ.get("HELM_BIN", "helm"),
                "--file", str(ROOT / "k8s/helmfile.yaml.gotmpl"), "build",
            ], cwd=ROOT / "k8s", env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            documents = list(yaml.safe_load_all(result.stdout))
            releases = [release for document in documents if document for release in document.get("releases", [])]
            by_name = {release["name"]: release for release in releases}
            self.assertEqual(set(by_name), {"self-serve-server-preprod", "self-serve-ui-preprod", "self-serve-ingress-preprod"})
            self.assertIs(by_name["self-serve-server-preprod"]["waitForJobs"], True)
            for release in releases:
                self.assertEqual(release["namespace"], "self-serve-preprod-ns")
            ingress = by_name["self-serve-ingress-preprod"]
            values = {}
            for block in ingress["values"]:
                values.update(block)
            self.assertIs(values["ingress"]["deploy"], False)
            server_values = {}
            for block in by_name["self-serve-server-preprod"]["values"]:
                server_values.update(block)
            self.assertEqual(server_values["secrets"]["provider"], "GCP")
            self.assertEqual(server_values["secrets"]["existingSecret"], "runtime")
            ui = by_name["self-serve-ui-preprod"]
            self.assertIn("self-serve-preprod-ns/self-serve-server-preprod", ui["needs"])
            dependencies = next(value["dependencies"] for value in ui["values"] if "dependencies" in value)
            self.assertEqual(dependencies["self-serve-server"], "self-serve-server-private-preprod-svc.self-serve-preprod-ns.svc.cluster.local")

    def _build(self, fixtures):
        """Render the real Helmfile against a throwaway values directory and return releases by name."""
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for filename, content in fixtures.items():
                (folder / filename).write_text(yaml.safe_dump(content))
            env = {**os.environ, "HELMFILE_VALUES_DIR": directory}
            env.pop("ARTIFACTS_CHANNEL", None)
            env.pop("ARTIFACTS_VERSION", None)
            result = subprocess.run([
                os.environ.get("HELMFILE_BIN", "helmfile"), "--helm-binary", os.environ.get("HELM_BIN", "helm"),
                "--file", str(ROOT / "k8s/helmfile.yaml.gotmpl"), "build",
            ], cwd=ROOT / "k8s", env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            documents = list(yaml.safe_load_all(result.stdout))
            releases = [release for document in documents if document for release in document.get("releases", [])]
            return {release["name"]: release for release in releases}

    @staticmethod
    def _values(release):
        merged = {}
        for block in release["values"]:
            merged.update(block)
        return merged

    def _switch_fixtures(self, **provider_extra):
        """A self-serve-only environment with nothing said about its database."""
        provider = {
            "environment": "preprod", "stack": "self-serve", "deployment_mode": "managed",
            "clusterDomain": "svc.cluster.local",
            "platform": {"provider": "GCP", "gcp": {"secretsProjectId": "test-project"}},
            "imagePullSecretConfig": {"enabled": False}, "ingress": {"deploy": True},
            "secrets": {"provider": "OPENBAO", "openbao": {"addr": "http://global"}},
        }
        provider.update(provider_extra)
        return {
            "provider.yaml": provider,
            "artifacts.yaml": {
                "chartBasePath": str(ROOT.parent / "divyam-helm-charts/charts"),
                "self-serve-server": {"values": {}}, "self-serve-ui": {"values": {}},
                "self-serve-postgres": {"values": {}},
                "cloudnative-pg-operator": {"values": {}},
                "divyam-router-controller": {"values": {}}, "mysql": {"enabled": False, "values": {}},
            },
            "resources.yaml": {"settings": {}, "charts": {}},
        }

    def test_an_undeclared_switch_database_deploys_in_cluster_and_is_pointed_at(self):
        """No declared host: self-serve-postgres comes up and the server gets its CNPG read-write Service."""
        by_name = self._build(self._switch_fixtures())
        self.assertIn("self-serve-postgres-preprod", by_name)
        self.assertEqual(by_name["self-serve-postgres-preprod"]["namespace"], "self-serve-preprod-ns")
        # The operator has to be selected even though its namespace group belongs to evalm8.
        self.assertIn("cloudnative-pg-operator-preprod", by_name)
        self.assertIn(
            "cnpg-operator-preprod-ns/cloudnative-pg-operator-preprod",
            by_name["self-serve-postgres-preprod"]["needs"],
        )
        server = by_name["self-serve-server-preprod"]
        self.assertIn("self-serve-preprod-ns/self-serve-postgres-preprod", server["needs"])
        self.assertEqual(
            self._values(server)["database"],
            {"host": "self-serve-postgres-preprod-rw.self-serve-preprod-ns.svc.cluster.local", "port": 5432},
        )

    def test_a_declared_switch_database_skips_the_chart_and_leaves_no_dangling_need(self):
        """Cloud SQL: the chart is not deployed, the declared host is used, and nothing needs the absent release."""
        by_name = self._build(self._switch_fixtures(
            databases={"self-serve-postgres": {"host": "10.25.0.12", "port": 5433}}))
        self.assertNotIn("self-serve-postgres-preprod", by_name)
        server = by_name["self-serve-server-preprod"]
        self.assertEqual(self._values(server)["database"], {"host": "10.25.0.12", "port": 5433})
        # A need on a release that was never rendered is an undefined-release error, not a dropped edge.
        self.assertNotIn("self-serve-preprod-ns/self-serve-postgres-preprod", server.get("needs", []))

    def test_a_host_declared_the_old_way_on_the_chart_still_wins(self):
        """preprod sets database.host in its own config.yaml; that predates the provider.yaml key and must keep working."""
        fixtures = self._switch_fixtures()
        fixtures["resources.yaml"]["charts"]["self-serve-server"] = {
            "values": {"database": {"connection": "tcp", "host": "10.25.0.12"}}}
        by_name = self._build(fixtures)
        self.assertNotIn("self-serve-postgres-preprod", by_name)
        self.assertEqual(self._values(by_name["self-serve-server-preprod"])["database"]["host"], "10.25.0.12")

    def test_identity_module_matches_the_chart_namespace(self):
        """Evaluate stack gating and the workload-identity namespace using OpenTofu plans."""
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            module = ROOT / "iac/2-app/1-iam_bindings/common"
            for source in module.glob("*.tf"):
                shutil.copyfile(source, folder / source.name)
            (folder / "tests").mkdir()
            shutil.copyfile(Path(__file__).with_name("self_serve_iam.tftest.hcl"), folder / "tests/self_serve_iam.tftest.hcl")
            tofu = os.environ.get("TOFU_BIN", "tofu")
            for command in (["init", "-backend=false"], ["test"]):
                result = subprocess.run([tofu, *command], cwd=folder, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
