#!/usr/bin/env python3
"""Fetch the complete pinned JSONSchema corpus, or verify its offline cache."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import unquote, urldefrag, urljoin
from urllib.request import urlopen


RESOURCES = Path(__file__).resolve().parents[1] / "JSONSchemaBenchmarks/Resources"
MANIFEST = RESOURCES / "real-world-manifest.json"
DESTINATION = RESOURCES / "RealWorld"
DIALECT = "https://json-schema.org/draft/2020-12/schema"


def read_manifest(path):
    manifest = json.loads(path.read_text())
    assets = [asset for source in manifest["sources"] for asset in source["assets"]]
    names = [asset["file"] for asset in assets]
    if not assets or len(names) != len(set(names)):
        raise ValueError("Manifest must have a nonempty, unique asset inventory")
    for asset in assets:
        if not re.fullmatch(r"[a-zA-Z0-9._-]+", asset["file"]):
            raise ValueError(f"Unsafe asset filename: {asset['file']}")
        if not re.fullmatch(r"[0-9a-f]{64}", asset["sha256"]):
            raise ValueError(f"Invalid SHA256: {asset['file']}")
        if not re.fullmatch(
            r"https://raw\.githubusercontent\.com/[\w.-]+/[\w.-]+/[0-9a-f]{40}/[^?#]+",
            asset["url"],
        ):
            raise ValueError(f"Asset URL must pin an immutable Git commit: {asset['file']}")
    for source in manifest["sources"]:
        if source["schema"] not in names or source["licenseFile"] not in names:
            raise ValueError(f"Missing schema/license asset: {source['name']}")
    return manifest


def checked_bytes(path, asset):
    if not path.is_file():
        raise ValueError(f"Missing corpus asset: {path}")
    data = path.read_bytes()
    actual = hashlib.sha256(data).hexdigest()
    if actual != asset["sha256"]:
        raise ValueError(
            f"Checksum mismatch for {path}: expected {asset['sha256']}, got {actual}"
        )
    return data


def verify_references(documents):
    """Fail closed on an unsupported dialect or any unpinned/unresolved reference."""
    resources = {}
    anchors = {}
    references = []

    def visit(value, base):
        if isinstance(value, list):
            for child in value:
                visit(child, base)
        elif isinstance(value, dict):
            if "$schema" in value and value["$schema"] != DIALECT:
                raise ValueError(f"Unsupported schema dialect: {value['$schema']}")
            if "$id" in value:
                base = urljoin(base, value["$id"])
                resources[base] = value
            for keyword in ("$anchor", "$dynamicAnchor"):
                if keyword in value:
                    anchors[f"{base}#{value[keyword]}"] = value
            for keyword in ("$ref", "$dynamicRef"):
                if keyword in value:
                    references.append(urljoin(base, value[keyword]))
            # Only schema-valued keywords contain subschemas. A property's name
            # may itself be "$ref"; examples/defaults are arbitrary instance data.
            for keyword in ("$defs", "definitions", "properties", "patternProperties",
                            "dependentSchemas"):
                for child in value.get(keyword, {}).values():
                    visit(child, base)
            for keyword in ("items", "additionalProperties", "unevaluatedProperties",
                            "unevaluatedItems", "contains", "propertyNames", "not",
                            "if", "then", "else", "contentSchema"):
                if keyword in value:
                    visit(value[keyword], base)
            for keyword in ("allOf", "anyOf", "oneOf", "prefixItems"):
                for child in value.get(keyword, []):
                    visit(child, base)

    for document in documents:
        if document.get("$schema") != DIALECT or not document.get("$id"):
            raise ValueError("Corpus roots must declare draft 2020-12 and an absolute $id")
        visit(document, document["$id"])
    for reference in references:
        resource, fragment = urldefrag(reference)
        if resource not in resources:
            raise ValueError(f"Unpinned external schema reference: {reference}")
        fragment = unquote(fragment)
        if not fragment:
            continue
        if not fragment.startswith("/"):
            if f"{resource}#{fragment}" not in anchors:
                raise ValueError(f"Unresolved schema anchor: {reference}")
            continue
        value = resources[resource]
        try:
            for token in fragment[1:].split("/"):
                token = token.replace("~1", "/").replace("~0", "~")
                value = value[int(token)] if isinstance(value, list) else value[token]
        except (KeyError, IndexError, ValueError, TypeError) as error:
            raise ValueError(f"Unresolved schema pointer: {reference}") from error
        if not isinstance(value, (dict, bool)):
            raise ValueError(f"Reference does not target a schema: {reference}")


def verify(directory, manifest):
    for source in manifest["sources"]:
        for asset in source["assets"]:
            checked_bytes(directory / asset["file"], asset)
    documents = [
        json.loads((directory / asset["file"]).read_bytes())
        for source in manifest["sources"]
        for asset in source["assets"]
        if asset["kind"] == "schema"
    ]
    verify_references(documents)


def download(url):
    with urlopen(url, timeout=60) as response:
        return response.read()


def fetch(manifest, destination, offline=False, downloader=download):
    assets = [asset for source in manifest["sources"] for asset in source["assets"]]
    if offline:
        verify(destination, manifest)
        print(f"Verified all {len(assets)} corpus assets offline")
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Publish a complete verified directory, never a prefix of a successful download.
    with tempfile.TemporaryDirectory(prefix=".schema-corpus-", dir=destination.parent) as temporary:
        stage = Path(temporary) / "new"
        stage.mkdir()
        for asset in assets:
            cached = destination / asset["file"]
            try:
                data = checked_bytes(cached, asset)
                print(f"Verified cached {asset['file']}")
            except ValueError as error:
                print(f"{error}; downloading pinned replacement", file=sys.stderr)
                data = downloader(asset["url"])
            (stage / asset["file"]).write_bytes(data)
            checked_bytes(stage / asset["file"], asset)
        verify(stage, manifest)
        backup = Path(temporary) / "previous"
        if destination.exists():
            destination.rename(backup)
        try:
            stage.rename(destination)
        except OSError:
            if backup.exists():
                backup.rename(destination)
            raise
    print(f"Installed complete corpus: {len(assets)} verified assets")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="Verify all cached assets; no network")
    arguments = parser.parse_args()
    try:
        fetch(read_manifest(MANIFEST), DESTINATION, offline=arguments.offline)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"error: {error}\n")


if __name__ == "__main__":
    main()
