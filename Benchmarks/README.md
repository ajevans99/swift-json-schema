# OrderedJSON benchmarks

Performance benchmarks for `OrderedJSON`'s parser and serializer, using [`ordo-one/package-benchmark`](https://github.com/ordo-one/package-benchmark) and comparing against Foundation's `JSONDecoder` / `JSONEncoder` / `JSONSerialization`.

## Running locally

You'll need the `jemalloc` system library (a `package-benchmark` dependency for memory metrics).

**macOS:**

```bash
brew install jemalloc
```

**Ubuntu / Debian:**

```bash
sudo apt-get install libjemalloc-dev
```

Then run:

```bash
cd Benchmarks
swift package --allow-writing-to-package-directory benchmark
```

This compiles in release mode and runs each benchmark for up to 2 seconds, reporting wall-clock time, total CPU time, and `malloc` count. Output goes to stdout as a set of percentile tables.

## What gets benchmarked

For each file in [`OrderedJSONBenchmarks/Resources/`](./OrderedJSONBenchmarks/Resources/):

- **`parse · <file> · OrderedJSON`** — `JSONValue.parse(data)`
- **`parse · <file> · JSONDecoder`** — `JSONDecoder().decode(JSONValue.self, from: data)`, the `Codable` route
- **`parse · <file> · JSONSerialization`** — `JSONSerialization.jsonObject(with:)`, the untyped Foundation route
- **`serialize · <file> · OrderedJSON`** — `value.serializedData()`
- **`serialize · <file> · JSONEncoder.sortedKeys`** — `JSONEncoder` with `.sortedKeys` (the apples-to-apples comparison since it's the only Foundation flag that produces stable output across processes)
- **`roundtrip · <file> · OrderedJSON`** — full `parse → emit → parse` cycle (the workload that motivated `OrderedJSON` in the first place — see [#149](https://github.com/ajevans99/swift-json-schema/issues/149))

## Corpus

Five committed files cover the workload space without requiring external downloads:

| File | Size | Shape |
|------|------|-------|
| `small.json` | 8 B | Smallest possible object. Measures fixed parser overhead, not throughput. |
| `wide-object.json` | 1.9 KB | 100 string-keyed scalar properties. Stresses object key handling. |
| `deep-array.json` | 0.1 KB | 50 levels of nested arrays. Stresses recursion / depth tracking. |
| `poll-instance.json` | 0.7 KB | A real-world `Poll`-shaped instance. Mixed types, modest nesting. |
| `users-array.json` | 26 KB | 100 user records with metadata. Large-ish wide+nested mix. |

Larger reference files (`canada.json`, `citm_catalog.json`, `twitter.json`) are intentionally not vendored — they're in the multi-MB range and would inflate the repo. See [#162](https://github.com/ajevans99/swift-json-schema/issues/162) for the plan to optionally fetch them at benchmark time.

## Adding a new case

1. Drop a `.json` file into [`OrderedJSONBenchmarks/Resources/`](./OrderedJSONBenchmarks/Resources/).
2. Add its name to the `names` array in [`OrderedJSONBenchmarks.swift`](./OrderedJSONBenchmarks/OrderedJSONBenchmarks.swift) (under `Corpus.load`).
3. Re-run `swift package --allow-writing-to-package-directory benchmark` from the `Benchmarks/` directory.

The corresponding parse/serialize/roundtrip benchmarks are generated automatically.

## Baselines and CI

Baseline tracking and PR-time regression checks are tracked in [#162](https://github.com/ajevans99/swift-json-schema/issues/162). For now, this PR establishes only the local-run infrastructure; baselines and CI integration ship separately.
