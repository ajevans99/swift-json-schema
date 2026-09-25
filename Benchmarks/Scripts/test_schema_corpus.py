"""Offline download-integrity, transactional-cache, and reference-closure tests."""

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from fetch_schema_corpus import DIALECT, fetch, read_manifest, verify_references
from check_schema_inventory import check, expected_inventory


class SchemaCorpusTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.destination = self.root / "corpus"
        schema = {
            "$schema": DIALECT,
            "$id": "https://example.org/schema",
            "$defs": {"name": {"type": "string"}},
            "properties": {"name": {"$ref": "#/$defs/name"}},
        }
        self.schema = schema
        self.payloads = {
            "test.schema.json": json.dumps(schema).encode(),
            "test.LICENSE": b"Test license fixture",
        }
        self.manifest = {"sources": [{
            "name": "test", "schema": "test.schema.json", "licenseFile": "test.LICENSE",
            "assets": [{
                "file": name, "kind": "schema" if name.endswith(".json") else "license",
                "url": f"https://raw.githubusercontent.com/test/repo/{'a' * 40}/{name}",
                "sha256": hashlib.sha256(data).hexdigest(),
            } for name, data in self.payloads.items()],
        }]}
        self.calls = []

    def download(self, url):
        self.calls.append(url)
        return self.payloads[url.rsplit("/", 1)[1]]

    def populate(self):
        fetch(self.manifest, self.destination, downloader=self.download)

    def test_download_then_offline_and_cached_runs_need_no_network(self):
        self.populate()
        self.assertEqual(len(self.calls), 2)
        self.calls.clear()
        fetch(self.manifest, self.destination, offline=True, downloader=self.download)
        fetch(self.manifest, self.destination, downloader=self.download)
        self.assertEqual(self.calls, [])
        self.assertEqual(sorted(p.name for p in self.destination.iterdir()), sorted(self.payloads))

    def test_missing_and_corrupt_offline_cache_fail(self):
        with self.assertRaisesRegex(ValueError, "Missing"):
            fetch(self.manifest, self.destination, offline=True)
        self.populate()
        (self.destination / "test.schema.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
            fetch(self.manifest, self.destination, offline=True)
        self.calls.clear()
        self.populate()
        self.assertEqual(len(self.calls), 1)

    def test_bad_download_never_publishes_partial_corpus(self):
        with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
            fetch(self.manifest, self.destination, downloader=lambda _: b"corrupt")
        self.assertFalse(self.destination.exists())
        self.assertEqual(list(self.root.iterdir()), [])

    def test_network_failure_preserves_previous_cache(self):
        self.populate()
        (self.destination / "test.LICENSE").unlink()
        before = (self.destination / "test.schema.json").read_bytes()

        def fail(_):
            raise OSError("connection failed")

        with self.assertRaisesRegex(OSError, "connection failed"):
            fetch(self.manifest, self.destination, downloader=fail)
        self.assertEqual((self.destination / "test.schema.json").read_bytes(), before)
        self.assertFalse((self.destination / "test.LICENSE").exists())
        self.assertEqual(list(self.root.iterdir()), [self.destination])

    def test_verified_bytes_must_also_be_valid_json(self):
        self.payloads["test.schema.json"] = b"{"
        self.manifest["sources"][0]["assets"][0]["sha256"] = hashlib.sha256(b"{").hexdigest()
        with self.assertRaises(ValueError):
            self.populate()
        self.assertFalse(self.destination.exists())

    def test_refs_and_dialect_fail_closed(self):
        verify_references([self.schema])
        for reference in ("https://missing.org/schema", "#/$defs/missing", "#missing"):
            schema = copy.deepcopy(self.schema)
            schema["$ref"] = reference
            with self.subTest(reference=reference), self.assertRaises(ValueError):
                verify_references([schema])
        schema = copy.deepcopy(self.schema)
        schema["$schema"] = "http://json-schema.org/draft-07/schema#"
        with self.assertRaisesRegex(ValueError, "draft 2020-12"):
            verify_references([schema])

    def test_root_ids_must_be_absolute_https_uris(self):
        roots = [{"$schema": DIALECT}]
        roots.extend(
            {"$schema": DIALECT, "$id": root_id}
            for root_id in (
                None, "", 42, [], {}, "schema.json", "/schema",
                "//example.org/schema", "http://example.org/schema",
                "ftp://example.org/schema", "https:relative", "https:///schema",
                "https://", "https://[invalid/schema",
            )
        )
        for schema in roots:
            with self.subTest(schema=schema), self.assertRaisesRegex(
                ValueError, r"absolute HTTPS \$id"
            ):
                verify_references([schema])

    def test_invalid_root_id_never_publishes_or_replaces_cache(self):
        for existing_cache in (False, True):
            with self.subTest(existing_cache=existing_cache):
                if existing_cache:
                    self.populate()
                schema = {**self.schema, "$id": "http://example.org/schema"}
                data = json.dumps(schema).encode()
                manifest = copy.deepcopy(self.manifest)
                manifest["sources"][0]["assets"][0]["sha256"] = hashlib.sha256(data).hexdigest()

                def download(url):
                    return data if url.endswith(".json") else self.download(url)

                with self.assertRaisesRegex(ValueError, r"absolute HTTPS \$id"):
                    fetch(manifest, self.destination, downloader=download)
                if existing_cache:
                    self.assertEqual(
                        {path.name: path.read_bytes() for path in self.destination.iterdir()},
                        self.payloads,
                    )
                else:
                    self.assertFalse(self.destination.exists())
                self.assertEqual(
                    list(self.root.iterdir()), [self.destination] if existing_cache else []
                )

    def test_relative_subschema_ids_remain_supported(self):
        schema = copy.deepcopy(self.schema)
        schema["$defs"]["name"]["$id"] = "name"
        schema["properties"]["name"]["$ref"] = "name"
        verify_references([schema])

    def test_pinned_cross_document_and_dynamic_refs(self):
        root = {**self.schema, "$ref": "https://example.org/remote"}
        remote = {"$schema": DIALECT, "$id": "https://example.org/remote",
                  "$dynamicAnchor": "node", "items": {"$dynamicRef": "#node"}}
        verify_references([root, remote])

    def test_manifest_rejects_unpinned_urls_paths_and_hashes(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.manifest))
        read_manifest(path)
        for key, value in (("url", "https://example.org/latest"),
                           ("file", "../escape"), ("sha256", "bad")):
            manifest = copy.deepcopy(self.manifest)
            manifest["sources"][0]["assets"][0][key] = value
            path.write_text(json.dumps(manifest))
            with self.subTest(key=key), self.assertRaises(ValueError):
                read_manifest(path)

    def test_full_inventory_rejects_partial_discovery_and_duplicates(self):
        for extended, count in ((False, 104), (True, 116)):
            names = sorted(expected_inventory(extended))
            self.assertEqual(check("\n".join(names), extended), count)
            for broken in (names[:-1], names + [names[0]], []):
                with self.assertRaises(ValueError):
                    check("\n".join(broken), extended)

    def test_reference_named_properties_and_examples_are_not_ref_keywords(self):
        schema = copy.deepcopy(self.schema)
        schema["properties"]["$ref"] = {"type": "string"}
        schema["examples"] = [{"$ref": "https://not-a-schema-dependency.example"}]
        verify_references([schema])


if __name__ == "__main__":
    unittest.main()
