"""Offline regression cases for baseline discovery and the CI coverage gate."""

import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT.parent / ".github/workflows/benchmarks.yml"
SCRIPT = ROOT / "Scripts/check-baseline-coverage.sh"
LISTING = """Target 'OrderedJSONBenchmarks' available benchmarks:
parse.small.OrderedJSON
serialize.small.OrderedJSON

Target 'JSONSchemaBenchmarks' available benchmarks:
validate.poll.Schema.validate
"""
BASELINES = [
    "OrderedJSONBenchmarks.parse.small.OrderedJSON.p90.json",
    "OrderedJSONBenchmarks.serialize.small.OrderedJSON.p90.json",
    "JSONSchemaBenchmarks.validate.poll.Schema.validate.p90.json",
]


def workflow_command(step_name):
    step = WORKFLOW.read_text().split(f"    - name: {step_name}\n", 1)[1]
    step = step.split("\n    - ", 1)[0]
    return textwrap.dedent(step.split("      run: |\n", 1)[1])


class BaselineCoverageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.baselines = self.root / "baselines"
        self.baselines.mkdir()
        self.listing = self.root / "listing"
        self.listing.write_text(LISTING)
        swift = self.root / "swift"
        swift.write_text(
            "#!/usr/bin/env bash\n"
            'printf "%s\\n" "$*" >> "$SWIFT_CALLS"\n'
            'cat "$SWIFT_LISTING"\n'
            'exit "$SWIFT_STATUS"\n'
        )
        swift.chmod(0o755)
        self.outputs = self.root / "outputs"
        self.env = {
            **os.environ,
            "PATH": f"{self.root}{os.pathsep}{os.environ['PATH']}",
            "BENCHMARK_BASELINE_PATH": str(self.baselines),
            "SWIFT_LISTING": str(self.listing),
            "SWIFT_CALLS": str(self.root / "calls"),
            "SWIFT_STATUS": "0",
            "GITHUB_OUTPUT": str(self.outputs),
        }

    def run_script(self):
        return subprocess.run(
            ["bash", str(SCRIPT)], env=self.env,
            capture_output=True, text=True,
        )

    def run_gate(self):
        return subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c",
             workflow_command("Check baseline coverage")],
            cwd=ROOT.parent, env=self.env, capture_output=True, text=True,
        )

    def populate_baselines(self):
        for name in BASELINES:
            (self.baselines / name).write_text("{}")

    def test_complete_coverage(self):
        self.populate_baselines()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.outputs.read_text(), "complete=true\n")

    def test_missing_baselines_allow_explicit_generation(self):
        (self.baselines / BASELINES[0]).write_text("{}")
        result = self.run_script()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn(BASELINES[0], result.stderr)
        for name in BASELINES[1:]:
            self.assertIn(name, result.stderr)
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.outputs.read_text(), "complete=false\n")

    def test_discovery_failures_stop_the_workflow(self):
        self.populate_baselines()
        for exit_code in (1, 2, 17, 127, 137):
            with self.subTest(exit_code=exit_code):
                self.env["SWIFT_STATUS"] = str(exit_code)
                result = self.run_script()
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("Failed to list benchmark targets.", result.stderr)
                result = self.run_gate()
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(self.outputs.exists())

    def test_empty_or_unrecognized_discovery_stops_the_workflow(self):
        for listing in ("", "Unexpected output\n", "Target 'Empty' available benchmarks:\n"):
            with self.subTest(listing=listing):
                self.listing.write_text(listing)
                result = self.run_script()
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("No benchmarks found", result.stderr)
                result = self.run_gate()
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(self.outputs.exists())

    def test_generation_preserves_dependency_resolution(self):
        result = subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c",
             workflow_command("Generate benchmark baselines")],
            cwd=ROOT, env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "--disable-automatic-resolution",
            (self.root / "calls").read_text().split(),
        )

    def test_generation_matches_allocation_only_enforcement(self):
        generation = subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c",
             workflow_command("Generate benchmark baselines")],
            cwd=ROOT, env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(generation.returncode, 0, generation.stderr)
        enforcement = subprocess.run(
            ["bash", str(ROOT / "Scripts/check-thresholds.sh"),
             "OrderedJSONBenchmarks"],
            cwd=ROOT, env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(enforcement.returncode, 0, enforcement.stderr)
        calls = [
            shlex.split(line)
            for line in (self.root / "calls").read_text().splitlines()
        ]
        self.assertEqual(len(calls), 3)  # Capture, informational report, check.
        for call in (calls[0], calls[2]):
            metrics = [
                call[index + 1]
                for index, argument in enumerate(call)
                if argument == "--metric"
            ]
            self.assertEqual(metrics, ["mallocCountTotal"])


if __name__ == "__main__":
    unittest.main()
