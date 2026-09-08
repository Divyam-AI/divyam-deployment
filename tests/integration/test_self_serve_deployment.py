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
