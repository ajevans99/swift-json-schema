# Benchmarks

Performance benchmarks for `OrderedJSON`'s parser/serializer and `JSONSchema` validation hot paths, using [`ordo-one/package-benchmark`](https://github.com/ordo-one/package-benchmark).

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

Limit runs to one suite with `--target OrderedJSONBenchmarks` or `--target JSONSchemaBenchmarks`. This compiles in release mode and reports wall-clock time, total CPU time, and `malloc` count. Output goes to stdout as percentile tables.

## What gets benchmarked

### OrderedJSON

For each file in [`OrderedJSONBenchmarks/Resources/`](./OrderedJSONBenchmarks/Resources/):

- **`parse · <file> · OrderedJSON`** — `JSONValue.parse(data)`
- **`parse · <file> · JSONDecoder`** — `JSONDecoder().decode(JSONValue.self, from: data)`, the `Codable` route
- **`parse · <file> · JSONSerialization`** — `JSONSerialization.jsonObject(with:)`, the untyped Foundation route
- **`serialize · <file> · OrderedJSON`** — `value.serializedData()`
- **`serialize · <file> · JSONEncoder.sortedKeys`** — `JSONEncoder` with `.sortedKeys` (the apples-to-apples comparison since it's the only Foundation flag that produces stable output across processes)
- **`roundtrip · <file> · OrderedJSON`** — full `parse → emit → parse` cycle (the workload that motivated `OrderedJSON` in the first place — see [#149](https://github.com/ajevans99/swift-json-schema/issues/149))

### JSONSchema

For each schema/instance pair in [`JSONSchemaBenchmarks/Resources/`](./JSONSchemaBenchmarks/Resources/):

- **`construct · <schema> · Schema.init(rawSchema:)`** — schema construction from a parsed raw schema
- **`validate · <schema> · Schema.validate`** — validation of a representative valid instance
- **`output · <schema> · <level>`** — validation plus rendering for Flag, Basic, Detailed, and Verbose outputs

## Corpus

The OrderedJSON suite uses five committed files that cover the workload space without requiring external downloads:

| File | Size | Shape |
|------|------|-------|
| `small.json` | 8 B | Smallest possible object. Measures fixed parser overhead, not throughput. |
| `wide-object.json` | 1.9 KB | 100 string-keyed scalar properties. Stresses object key handling. |
| `deep-array.json` | 0.1 KB | 50 levels of nested arrays. Stresses recursion / depth tracking. |
| `poll-instance.json` | 0.7 KB | A real-world `Poll`-shaped instance. Mixed types, modest nesting. |
| `users-array.json` | 26 KB | 100 user records with metadata. Large-ish wide+nested mix. |

Larger reference files (`canada.json`, `citm_catalog.json`, `twitter.json`) are intentionally not vendored — they're in the multi-MB range and would inflate the repo. See [#162](https://github.com/ajevans99/swift-json-schema/issues/162) for the plan to optionally fetch them at benchmark time.

The JSONSchema suite uses three representative schemas: a Poll-shaped application schema, an OpenAPI path fragment, and the draft 2020-12 meta-schema.

## Adding a new case

1. Drop a `.json` file into [`OrderedJSONBenchmarks/Resources/`](./OrderedJSONBenchmarks/Resources/).
2. Add its name to the `names` array in [`OrderedJSONBenchmarks.swift`](./OrderedJSONBenchmarks/OrderedJSONBenchmarks.swift) (under `Corpus.load`).
3. Re-run `swift package --allow-writing-to-package-directory benchmark` from the `Benchmarks/` directory.

The corresponding parse/serialize/roundtrip benchmarks are generated automatically.

## Baselines and CI

Committed p90 threshold baselines live in [`Baselines/`](./Baselines/). CI runs both benchmark targets on `ubuntu-24.04`, checks current p90 wall-clock / CPU / malloc metrics against those baselines, and writes markdown tables to the GitHub Actions job summary.

To refresh baselines on the same runner class after an intentional improvement, run:

```bash
cd Benchmarks
rm -rf Baselines
swift package --allow-writing-to-package-directory benchmark thresholds update --path Baselines --no-progress
```

Benchmark numbers are runner-sensitive; refresh committed baselines only from the pinned CI runner or a matching environment.
