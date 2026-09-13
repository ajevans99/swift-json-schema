#!/usr/bin/env python3
"""Check complete JSONSchema discovery or result-table names read from stdin."""

import argparse
import re
import sys


def expected_inventory(extended=False):
    expected = set()
    for index, schema in enumerate((
        "poll", "openapi-fragment", "draft2020-12-schema",
        "regex-heavy", "reference-heavy", "combinator-heavy",
    )):
        expected.add(f"construct.{schema}.Schema.init")
        for suffix in (("", ".invalid") if index < 3 else (".valid", ".invalid")):
            expected.add(f"validate.{schema}{suffix}.Schema.validate")
            for level in ("flag", "basic", "detailed", "verbose"):
                expected.add(f"output.{schema}{suffix}.{level}")
    for schema in ("openapi-3.1", "overlay-1.0"):
        expected.add(f"construct.{schema}.Schema.init")
        for size in ((10, 100, 1000) if extended else (10, 100)):
            for variant in ("valid", "invalid-early", "invalid-late", "invalid-many"):
                expected.add(f"validate.{schema}.{size}.{variant}.Schema.validate")
                levels = ("basic", "verbose") if variant == "invalid-many" else ()
                if size == 10 and variant == "valid":
                    levels = ("basic",)
                if size == 10 and variant == "invalid-late":
                    levels = ("verbose",)
                for level in levels:
                    expected.add(f"output.{schema}.{size}.{variant}.{level}")
    return expected


def check(text, extended=False):
    names = re.findall(r"^(?:construct|validate|output)\.[^\n]+$", text, re.MULTILINE)
    expected = expected_inventory(extended)
    actual = set(names)
    if actual != expected or len(names) != len(actual):
        raise ValueError(
            f"Incomplete JSONSchema inventory: missing={sorted(expected - actual)}, "
            f"unexpected={sorted(actual - expected)}, duplicates={len(names) - len(actual)}"
        )
    return len(actual)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sizes", choices=("pr", "extended"), default="pr")
    arguments = parser.parse_args()
    try:
        count = check(sys.stdin.read(), extended=arguments.sizes == "extended")
        print(f"Verified complete JSONSchema inventory: {count} cases")
    except ValueError as error:
        parser.exit(2, f"error: {error}\n")
