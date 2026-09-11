#!/usr/bin/env python3
"""Classify diagnose.log using SwiftPM's exit status (passed as the only argument)."""

import os
from pathlib import Path
import re
import sys


def classify(exit_code, log):
    log = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", log)
    findings = re.findall(r"^\s*\U0001f494 API breakage: (.+)$", log, re.MULTILINE)
    # SwiftPM exits 1 for both API breaks and failures. Failed module comparisons
    # emit error diagnostics, even when other modules report valid API breakages.
    errors = re.search(r"(?:^|:\s)(?:fatal )?error:", log, re.MULTILINE | re.IGNORECASE)
    if not errors and exit_code == 0 and not findings:
        return "clean", findings
    if not errors and exit_code == 1 and findings:
        return "breaking", findings
    return "failed", findings


if __name__ == "__main__":
    exit_code = int(sys.argv[1])
    status, findings = classify(exit_code, Path("diagnose.log").read_text(errors="replace"))
    Path("api-findings.txt").write_text("\n".join(findings))
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"status={status}\nexit_code={exit_code}\n")
        output.write(f"count={len(findings) if status != 'failed' else ''}\n")
    if status == "failed":
        print("::error::API compatibility scan could not complete; see diagnose.log.")
        sys.exit(1)
