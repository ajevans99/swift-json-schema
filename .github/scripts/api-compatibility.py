#!/usr/bin/env python3
"""Run SwiftPM's API scan without mistaking its shared exit code 1 for success."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


FINDING = re.compile(r"^\s*\U0001f494 API breakage: (.+)$")
CLEAN = re.compile(r"^No breaking changes detected in (\S+)$")
BREAKING = re.compile(r"^([1-9][0-9]*) breaking changes? detected in (\S+):$")
SKIPPED = re.compile(r"^Skipping (\S+) because it does not exist in the baseline$")
ERROR = re.compile(r"(?:^|:\s)(?:fatal )?error:", re.IGNORECASE)
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def library_modules(description):
    # Match SwiftPM's apiDigesterModules: Swift modules directly vended by libraries,
    # not executable/test targets or all transitive product memberships.
    targets = {
        target
        for product in description["products"]
        if "library" in product["type"]
        for target in product["targets"]
    }
    return {
        target["c99name"]
        for target in description["targets"]
        if target["name"] in targets and target["module_type"] == "SwiftTarget"
    }


def classify(exit_code, log, modules):
    findings = []
    completed = {}
    reported = {}
    skipped = set()
    current_module = None
    invalid = False
    errors = False
    for line in ANSI.sub("", log).splitlines():
        if match := FINDING.fullmatch(line):
            findings.append(match[1])
            if current_module is None:
                invalid = True
            else:
                reported[current_module] = reported.get(current_module, 0) + 1
            continue
        errors |= ERROR.search(line) is not None
        if match := CLEAN.fullmatch(line):
            module, count = match[1], 0
        elif match := BREAKING.fullmatch(line):
            module, count = match[2], int(match[1])
        elif match := SKIPPED.fullmatch(line):
            module, count = match[1], None
        else:
            continue
        invalid |= module in completed or module in skipped
        if count is None:
            skipped.add(module)
            current_module = None
        else:
            completed[module] = count
            current_module = module

    reason = ""
    if exit_code not in (0, 1):
        reason = f"Swift exited with unexpected status {exit_code}."
    elif errors:
        reason = "Swift reported tool, build, or dependency errors."
    elif not modules or not completed or invalid or (completed.keys() | skipped) != modules:
        reason = "Missing, duplicate, or unrecognized library-module completion records."
    elif any(reported.get(module, 0) != count for module, count in completed.items()):
        reason = "The reported breakage count does not match the diagnostic output."
    elif exit_code != (1 if findings else 0):
        reason = "Swift's exit status does not match a completed clean or breaking scan."
    return ("failed" if reason else "breaking" if findings else "clean"), findings, skipped, reason


def run_swift(arguments, stdout, stderr=None):
    with stdout.open("w") as output:
        try:
            if stderr is None:
                return subprocess.run(
                    ["swift", "package", *arguments], stdout=output, stderr=subprocess.STDOUT
                ).returncode
            with stderr.open("w") as errors:
                return subprocess.run(
                    ["swift", "package", *arguments], stdout=output, stderr=errors
                ).returncode
        except OSError as error:
            # Command-not-found/launch failures must still produce a failed report.
            with (stderr or stdout).open("a") as errors:
                errors.write(f"error: could not launch swift: {error}\n")
            return 127


def report(context, baseline, status, findings, skipped, reason, exit_code):
    if status == "failed":
        heading = "### API compatibility scan could not complete"
    elif status == "breaking":
        heading = f"### Public API breaking changes detected ({len(findings)})"
    else:
        heading = "### No public API breaking changes detected"
    lines = [heading, "", f"Compared against `{baseline}` using "
             "`swift package diagnose-api-breaking-changes`.", ""]
    if status == "failed":
        lines += [
            f"**Scan failed:** {reason}",
            f"Diagnose exit status: `{exit_code}`.",
            "API compatibility is **unknown**. No existing `breaking-change` label "
            "is removed or changed based on this scan.",
            "",
        ]
    if findings:
        lines += (["Partial findings (not a complete scan):", ""] if status == "failed" else [])
        lines += ["```text", *findings, "```", ""]
    if status == "breaking" and context == "pr":
        lines += [
            "Intentional breaks are supported and do not fail this check. For same-repository "
            "PRs, the `breaking-change` label tracks these changes. If accidental, restore "
            "the symbols or add deprecation shims.",
            "",
        ]
    if skipped:
        lines += ["Modules absent from the baseline (not compared): "
                  + ", ".join(f"`{module}`" for module in sorted(skipped)) + ".", ""]
    lines += [
        ("This check shows only changes this PR introduces. Cumulative breakages since "
         "the last release tag are reviewed at release time.")
        if context == "pr" else
        "This report covers cumulative public API changes since the baseline release.",
        "",
        "See the job summary and `api-compatibility-diagnostics` artifact for diagnostic logs.",
        "",
    ]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--context", choices=("pr", "release"), required=True)
    args = parser.parse_args()

    status, findings, skipped, reason = "failed", [], set(), ""
    exit_code = "not run"
    describe_code = run_swift(["describe", "--type", "json"], Path("package.json"), Path("describe.log"))
    if describe_code != 0:
        reason = f"Could not determine library modules (swift package describe exited {describe_code})."
    else:
        try:
            modules = library_modules(json.loads(Path("package.json").read_text()))
        except (ValueError, KeyError, TypeError) as error:
            reason = f"Could not parse library modules: {error}"
        else:
            exit_code = run_swift(
                ["diagnose-api-breaking-changes", args.baseline], Path("diagnose.log")
            )
            status, findings, skipped, reason = classify(
                exit_code, Path("diagnose.log").read_text(errors="replace"), modules
            )

    body = report(args.context, args.baseline, status, findings, skipped, reason, exit_code)
    Path("api-report.md").write_text(body)
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a") as stream:
            stream.write(f"status={status}\nexit_code={exit_code}\n")
            # An incomplete scan has no authoritative count, even with partial findings.
            stream.write(f"count={len(findings) if status != 'failed' else ''}\n")
    for name in ("describe.log", "diagnose.log"):
        if Path(name).exists():
            print(Path(name).read_text(errors="replace"))
    print(body)
    if status == "failed":
        print("::error::API compatibility scan could not complete; see diagnostic logs.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
