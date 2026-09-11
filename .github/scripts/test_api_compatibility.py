"""Offline regression cases for the shared classifier and its workflow outputs."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("api-compatibility.py")
CLEAN = "No breaking changes detected in OrderedJSON\n"
BREAKING = (
    "1 breaking change detected in OrderedJSON:\n"
    "  \U0001f494 API breakage: func removed() has been removed\n"
)


class APICompatibilityTests(unittest.TestCase):
    def test_scan_outcomes(self):
        cases = [
            ("clean", 0, CLEAN, "clean"),
            ("breaking", 1, BREAKING, "breaking"),
            ("invalid baseline", 1, "error: Could not get revision", "failed"),
            ("build failure", 1, "File.swift:12:3: error: cannot find type", "failed"),
            ("dependency failure", 1, "error: Failed to clone repository", "failed"),
            ("incomplete scan", 1, CLEAN, "failed"),
            ("no output", 1, "", "failed"),
            ("command missing", 127, "swift: command not found", "failed"),
            ("unexpected exit", 2, BREAKING, "failed"),
            ("signal", 137, BREAKING, "failed"),
            ("inconsistent exit", 0, BREAKING, "failed"),
            ("zero with error", 0, CLEAN + "error: digester failed", "failed"),
            ("partial results", 1, BREAKING + "error: failed to read API digester output for JSONSchema", "failed"),
            ("fatal error", 1, BREAKING + "fatal error: digester crashed", "failed"),
            ("colored error", 1, BREAKING + "\x1b[31merror:\x1b[0m failed", "failed"),
            ("colored findings", 1, "\x1b[31m" + BREAKING + "\x1b[0m", "breaking"),
            ("build warning", 1, "File.swift:0: warning: API breakage: removed\n" + BREAKING, "breaking"),
            ("unrecognized finding", 1, "New diagnostic format", "failed"),
        ]
        for name, exit_code, log, status in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "diagnose.log").write_text(log)
                result = subprocess.run(
                    [sys.executable, str(SCRIPT), str(exit_code)],
                    cwd=root, capture_output=True, text=True,
                    env={**os.environ, "GITHUB_OUTPUT": str(root / "outputs")},
                )
                self.assertEqual(result.returncode, 1 if status == "failed" else 0, result.stderr)
                outputs = dict(line.split("=", 1) for line in (root / "outputs").read_text().splitlines())
                self.assertEqual(outputs, {
                    "status": status, "exit_code": str(exit_code),
                    "count": "" if status == "failed" else "1" if status == "breaking" else "0",
                })
                self.assertEqual("::error::" in result.stdout, status == "failed")
                self.assertEqual((root / "diagnose.log").read_text(), log)
                if "func removed()" in log:
                    self.assertEqual((root / "api-findings.txt").read_text(), "func removed() has been removed")


if __name__ == "__main__":
    unittest.main()
