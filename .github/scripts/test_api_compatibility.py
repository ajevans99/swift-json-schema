"""Hermetic regression tests: no Swift installation, network, or third-party packages."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("api-compatibility.py")
SPEC = importlib.util.spec_from_file_location("api_compatibility", SCRIPT)
scan = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scan)

MODULES = ("OrderedJSON", "JSONSchema", "JSONSchemaBuilder", "JSONSchemaConversion")
DESCRIPTION = {
    "products": [
        {"name": name, "type": {"library": ["automatic"]}, "targets": [name]}
        for name in MODULES
    ] + [{"name": "Client", "type": {"executable": None}, "targets": ["Client"]}],
    "targets": [
        {"name": name, "c99name": name, "module_type": "SwiftTarget"}
        for name in (*MODULES, "Client", "Tests", "Macro")
    ],
}
CLEAN = "\n".join(f"No breaking changes detected in {name}" for name in MODULES) + "\n"
BREAKING = CLEAN.replace(
    "No breaking changes detected in OrderedJSON",
    "1 breaking change detected in OrderedJSON:\n"
    "  \U0001f494 API breakage: func removed() has been removed",
)
MOCK_SWIFT = """#!/usr/bin/env python3
import os
import sys

if sys.argv[1:] == ["package", "describe", "--type", "json"]:
    print(os.environ["MOCK_DESCRIPTION"])
    print(os.environ.get("MOCK_DESCRIBE_ERRORS", ""), file=sys.stderr)
    sys.exit(int(os.environ.get("MOCK_DESCRIBE_EXIT", "0")))
assert sys.argv[1:] == [
    "package", "diagnose-api-breaking-changes", os.environ["MOCK_BASELINE"]
], sys.argv
print(os.environ["MOCK_LOG"], end="")
print(os.environ.get("MOCK_ERRORS", ""), file=sys.stderr)
sys.exit(int(os.environ["MOCK_EXIT"]))
"""


class APICompatibilityTests(unittest.TestCase):
    def invoke(self, log=CLEAN, exit_code=0, context="pr", **extra_env):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / "bin"
            binary.mkdir()
            swift = binary / "swift"
            swift.write_text(MOCK_SWIFT)
            swift.chmod(0o755)
            output = root / "output"
            env = {
                **os.environ,
                "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                "GITHUB_OUTPUT": str(output),
                "MOCK_DESCRIPTION": json.dumps(DESCRIPTION),
                "MOCK_BASELINE": "baseline with spaces; not a shell command",
                "MOCK_LOG": log,
                "MOCK_EXIT": str(exit_code),
                **extra_env,
            }
            process = subprocess.run(
                [sys.executable, str(SCRIPT), "--context", context, "--baseline", env["MOCK_BASELINE"]],
                cwd=root, env=env, capture_output=True, text=True,
            )
            self.assertTrue(output.exists(), process.stderr)
            outputs = dict(line.split("=", 1) for line in output.read_text().splitlines())
            files = {
                name: (root / name).read_text()
                for name in ("api-report.md", "describe.log", "diagnose.log")
                if (root / name).exists()
            }
            return process, outputs, files

    def assert_failed(self, log, exit_code, **kwargs):
        process, outputs, files = self.invoke(log, exit_code, **kwargs)
        self.assertEqual(process.returncode, 1, process.stderr)
        self.assertEqual(outputs["status"], "failed")
        self.assertEqual(outputs["count"], "")
        self.assertIn("::error::API compatibility scan could not complete", process.stdout)
        body = files["api-report.md"]
        self.assertIn("API compatibility is **unknown**", body)
        self.assertIn("No existing `breaking-change` label is removed or changed", body)
        self.assertNotIn("### No public API breaking changes detected", body)
        if "diagnose.log" in files:
            self.assertIn(log, files["diagnose.log"])
        return outputs, files

    def test_clean_and_breaking_in_both_workflows(self):
        for context in ("pr", "release"):
            for log, code, status, count in ((CLEAN, 0, "clean", "0"), (BREAKING, 1, "breaking", "1")):
                with self.subTest(context=context, status=status):
                    process, outputs, files = self.invoke(log, code, context)
                    self.assertEqual(process.returncode, 0, process.stderr)
                    self.assertEqual(outputs, {"status": status, "count": count, "exit_code": str(code)})
                    self.assertIn(log, files["diagnose.log"])
                    self.assertNotIn("Scan failed", files["api-report.md"])
                    if status == "breaking":
                        self.assertIn("func removed() has been removed", files["api-report.md"])
                        if context == "pr":
                            self.assertIn("Intentional breaks are supported", files["api-report.md"])

    def test_invalid_baseline_build_and_dependency_failures(self):
        for context in ("pr", "release"):
            for error in (
                "error: Could not get revision missing^{commit}",
                "/tmp/Source.swift:12:3: error: cannot find type",
                "error: Failed to clone repository",
                "",
            ):
                with self.subTest(context=context, error=error):
                    self.assert_failed(error, 1, context=context)

    def test_partial_findings_and_tool_errors_are_not_completed_breaks(self):
        for errors in (
            "error: failed to read API digester output for JSONSchema",
            "/tmp/File.swift:5:2: error: module failed",
            "fatal error: digester crashed",
        ):
            with self.subTest(error=errors):
                _, files = self.assert_failed(BREAKING, 1, MOCK_ERRORS=errors)
                self.assertIn(errors, files["diagnose.log"])
                self.assertIn("Partial findings (not a complete scan)", files["api-report.md"])

    def test_errors_override_even_a_zero_exit(self):
        self.assert_failed(CLEAN, 0, MOCK_ERRORS="error: digester failed")

    def test_unexpected_exit_statuses(self):
        for code in (2, 127, 134, 137, 143):
            for log in (CLEAN, BREAKING):
                with self.subTest(code=code, log=log):
                    self.assert_failed(log, code)
        self.assertEqual(scan.classify(-9, BREAKING, set(MODULES))[0], "failed")

    def test_incomplete_and_unrecognized_results(self):
        for log in (
            "",
            "Build complete!\n",
            "  \U0001f494 API breakage: func removed() has been removed\n",
            BREAKING.replace("No breaking changes detected in JSONSchema\n", ""),
            BREAKING.replace("JSONSchemaConversion", "UnexpectedModule"),
            BREAKING + "No breaking changes detected in JSONSchema\n",
            BREAKING.replace("1 breaking change", "2 breaking changes"),
            BREAKING.replace("detected in OrderedJSON:", "found in OrderedJSON:"),
            CLEAN.replace("No breaking changes detected", "No API changes detected"),
        ):
            with self.subTest(log=log):
                self.assert_failed(log, 1 if "API breakage:" in log else 0)

    def test_exit_status_must_agree_with_findings(self):
        self.assert_failed(CLEAN, 1)
        self.assert_failed(BREAKING, 0)

    def test_plural_findings_and_module_order(self):
        log = (
            "No breaking changes detected in JSONSchemaConversion\n"
            "No breaking changes detected in JSONSchemaBuilder\n"
            "2 breaking changes detected in OrderedJSON:\n"
            "  \U0001f494 API breakage: func first() has been removed\n"
            "  \U0001f494 API breakage: func second() has been removed\n"
            "1 breaking change detected in JSONSchema:\n"
            "  \U0001f494 API breakage: func third() has been removed\n"
        )
        process, outputs, _ = self.invoke(log, 1)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(outputs["count"], "3")

    def test_findings_must_match_each_module_not_just_the_total(self):
        finding = "  \U0001f494 API breakage: func removed() has been removed\n"
        without_finding = BREAKING.replace(finding, "")
        self.assert_failed(finding + without_finding, 1)
        self.assert_failed(without_finding + finding, 1)

    def test_new_modules_absent_from_baseline_are_explicitly_skipped(self):
        log = CLEAN.replace(
            "No breaking changes detected in OrderedJSON",
            "Skipping OrderedJSON because it does not exist in the baseline",
        )
        process, outputs, files = self.invoke(log)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(outputs["status"], "clean")
        self.assertIn("Modules absent from the baseline (not compared): `OrderedJSON`", files["api-report.md"])

    def test_all_skipped_is_not_a_clean_comparison(self):
        log = "\n".join(f"Skipping {module} because it does not exist in the baseline" for module in MODULES)
        self.assert_failed(log, 0)

    def test_warnings_and_color_do_not_hide_real_findings(self):
        log = (
            "<unknown>:0: warning: API breakage: func removed() has been removed "
            "[#api-digester-breaking-change]\n" + BREAKING
        )
        log = "\x1b[31m" + log + "\x1b[0m"
        process, outputs, _ = self.invoke(log, 1)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(outputs["count"], "1")
        self.assert_failed(BREAKING, 1, MOCK_ERRORS="\x1b[31merror:\x1b[0m failed")

    def test_manifest_discovery_failures(self):
        _, files = self.assert_failed(
            "", 1, MOCK_DESCRIBE_EXIT="1", MOCK_DESCRIBE_ERRORS="error: invalid manifest"
        )
        self.assertIn("error: invalid manifest", files["describe.log"])
        self.assertNotIn("diagnose.log", files)
        for description in ("not json", "{}", '{"products": null}', '{"products": [], "targets": []}'):
            with self.subTest(description=description):
                self.assert_failed(CLEAN, 0, MOCK_DESCRIPTION=description)

    def test_only_swift_modules_vended_by_library_products_are_expected(self):
        description = json.loads(json.dumps(DESCRIPTION))
        description["products"].append({"type": {"library": ["static"]}, "targets": ["CModule", "a-b"]})
        description["targets"] += [
            {"name": "CModule", "c99name": "CModule", "module_type": "ClangTarget"},
            {"name": "a-b", "c99name": "a_b", "module_type": "SwiftTarget"},
        ]
        self.assertEqual(scan.library_modules(description), {*MODULES, "a_b"})

    def test_swift_launch_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "log"
            # An explicit missing executable tests OSError handling without relying on PATH.
            from unittest.mock import patch
            with patch.object(scan.subprocess, "run", side_effect=FileNotFoundError("swift missing")):
                code = scan.run_swift(["describe"], output)
            self.assertEqual(code, 127)
            self.assertIn("error: could not launch swift", output.read_text())


if __name__ == "__main__":
    unittest.main()
