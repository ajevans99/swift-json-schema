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
swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark
```

Limit runs to one suite with `--target OrderedJSONBenchmarks` or `--target JSONSchemaBenchmarks`. This compiles in release mode and reports wall-clock time, total CPU time, and `malloc` count. Output goes to stdout as percentile tables. The local package dependency is explicitly named so these commands also work in renamed clones and Git worktrees.

The committed corpus works offline. To include both downloaded corpora used
by CI, fetch them before building:

```bash
Benchmarks/Scripts/fetch-reference-corpus.sh
python3 Benchmarks/Scripts/fetch_schema_corpus.py
cd Benchmarks
JSONSCHEMA_BENCHMARK_CORPUS=required \
  swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark
```

The scripts download immutable upstream files and verify their SHA-256 checksums.
Downloaded schemas, licenses, and reference JSON files are ignored by Git.

## What gets benchmarked

### OrderedJSON

For each file in [`OrderedJSONBenchmarks/Resources/`](./OrderedJSONBenchmarks/Resources/):

- **`parse.<file>.OrderedJSON`** — `JSONValue.parse(data)`
- **`parse.<file>.JSONDecoder`** — `JSONDecoder().decode(JSONValue.self, from: data)`, the `Codable` route
- **`parse.<file>.JSONSerialization`** — `JSONSerialization.jsonObject(with:)`, the untyped Foundation route
- **`serialize.<file>.OrderedJSON`** — `value.serializedData()`
- **`serialize.<file>.JSONEncoder.sortedKeys`** — `JSONEncoder` with `.sortedKeys`, deterministic output with sorting rather than insertion-order preservation
- **`roundtrip.<file>.OrderedJSON`** — full `parse → emit → parse` cycle (the workload that motivated `OrderedJSON` in the first place — see [#149](https://github.com/ajevans99/swift-json-schema/issues/149))
- **`roundtrip.<file>.JSONDecoder.JSONEncoder.sortedKeys`** — decode `JSONValue`, encode with sorted keys, then decode `JSONValue` again
- **`roundtrip.<file>.JSONSerialization.sortedKeys`** — parse an untyped Foundation object graph, emit with sorted keys, then parse the emitted bytes again

These are workload comparisons, **not semantically interchangeable APIs**.
OrderedJSON preserves source object-key order (including its last-duplicate-wins
position rule). Foundation's keyed decoding does not promise that order, and
sorting produces a different order while doing additional work.
`JSONDecoder<JSONValue>` includes Codable dispatch and builds the same Swift
value type; `JSONSerialization` instead builds an untyped Foundation graph.
Number representation, duplicate-key handling, escaping, and encoded bytes
can differ. A successful Foundation round trip does not establish OrderedJSON's
ordering or byte-stability contract.

File I/O and the initial parse for serialize-only cases happen outside measurement.
Decoder/encoder construction and encoder configuration remain inside each measured
invocation, matching the existing parse/serialize cases. Round trips include both
parses and serialization; no stage is precomputed.

### Latency and throughput

OrderedJSON cases with inputs below 1 KiB report latency in nanoseconds; larger
ones use microseconds to avoid rounding multi-millisecond results to whole
milliseconds. Inputs of at least 16 KiB also report package-benchmark's built-in
**Throughput (# / s)**: documents/second for parse or serialize, and complete
cycles/second for round trips. There is no batching or byte-count scaling, so
time and allocations remain per operation, including on tiny inputs.

For parse input throughput in MiB/s, multiply documents/second by the exact
input size in bytes and divide by 1,048,576. Get that size with
`wc -c OrderedJSONBenchmarks/Resources/<file>.json`. Do not call this serializer
output throughput: emitted sizes can differ from the source and across APIs.
For a round trip, input-normalized throughput counts the source once, not three
times, and is not a count of all bytes traversed.

### Comparing a candidate locally

Use the same machine, toolchain, locked dependencies, fetched corpus, and release
configuration for both revisions. Measure timing separately from allocations:
instrumentation and machine load can affect timing, especially on tiny inputs.
For example, from `Benchmarks/`:

```bash
export SWIFT_DETERMINISTIC_HASHING=1
swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark \
  baseline update before-time-1 --target OrderedJSONBenchmarks \
  --metric wallClock --metric throughput --no-progress
swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark \
  baseline update before-alloc-1 --target OrderedJSONBenchmarks \
  --metric mallocCountTotal --no-progress
```

Repeat with unique names (`before-time-2`, `before-time-3` and corresponding
allocation runs), then repeat for the candidate using `after-*` names.
Inspect deltas from `Benchmarks/` with:

```bash
swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark \
  baseline compare before-time-1 after-time-1 --target OrderedJSONBenchmarks --no-progress
```

These local named baselines live under `.benchmarkBaselines`, not the committed
Linux thresholds in `Baselines`. Report per-run medians/p90s and their range,
not only the fastest run; inspect the whole corpus for tradeoffs.
Use `--filter '^parse\.(twitter|canada)\.OrderedJSON$'` for an initial focused
investigation, but not as a substitute for the broader comparison.

Profile the release workload (for example with Instruments Time Profiler on
macOS) separately from these measurements. Start with string-heavy Twitter and
numeric Canada. Neither string fast paths nor direct integer parsing are
justified until the profile and repeated candidate measurements support them.

### JSONSchema

The six committed schemas in [`JSONSchemaBenchmarks/Resources/`](./JSONSchemaBenchmarks/Resources/)
each have one valid and one invalid instance: **66 cases** total (6 construction,
12 warmed validation, and 48 validation-plus-output).

- **`construct.<schema>.Schema.init`** — one construction case per schema, not per instance
- **`validate.<schema>[.<validity>].Schema.validate`** — one validation per measured iteration, using a warmed schema
- **`output.<schema>[.<validity>].<level>`** — validation plus Flag, Basic, Detailed, or Verbose rendering; not rendering a cached result

The original valid Poll, OpenAPI fragment, and meta-schema cases retain their
names. New invalid cases use `.invalid`; the three new focused schemas explicitly
use `.valid` and `.invalid`.

| Schema | Valid workload | Invalid workload |
|--------|----------------|------------------|
| `poll` | Application object with nested options, settings, and category alternatives | Numeric bounds, empty option text, and an invalid category payload |
| `openapi-fragment` | Paths, operations, responses, and recursive component schema references | Version pattern, parameter enum, missing response description, and invalid component type |
| `draft2020-12-schema` | Full meta-schema validated against itself | Nested invalid keyword values and duplicate `required` entries |
| `regex-heavy` | 12 properties matched against four `patternProperties` expressions and their value patterns | Four malformed values spread across the patterns |
| `reference-heavy` | Six tree nodes with repeated local `$ref` resolution over three levels | Invalid child identifier and grandchild label |
| `combinator-heavy` | `allOf`, two successful `anyOf` branches, and exactly-one-match choices | Failed `anyOf`, both zero/multiple-match `oneOf`, and `allOf` label failures |

The combinator's `unevaluatedProperties: false` requires annotations from **both**
successful `anyOf` branches. It deliberately guards against treating naive
short-circuiting as a semantics-preserving optimization. The regex keywords
already compile patterns at schema construction time; these cases measure
matching and traversal, not a presumed missing regex cache.

All instance file I/O and parsing, expected-validity checks, and error-output
checks happen before measurement. Every invalid fixture declares expected leaf
errors by keyword and instance JSON Pointer. Preflight checks those errors in
the raw result and verifies their locations and nonempty messages survive Basic,
Detailed, and Verbose output, while Flag must equal the expected validity.
Each instance has its own schema warmed by these checks; no result is reused
inside measured closures. These preconditions run in the selected case's
**unmeasured setup**, before warmup and measurement, so a broken fixture fails
rather than recording misleading numbers. Discovery loads resources and lists
cases but does not validate instances; run the suite, not only `benchmark list`,
to exercise correctness. The runner launches a process per case, so validating
every large instance during every registration would multiply setup cost
unnecessarily.

Resource-schema construction starts from already-parsed JSON. The meta-schema
construction case intentionally retains `Dialect.draft2020_12.loadMetaSchema()`,
including that API's bundled-resource loading and complete remote-schema context;
it is not replaced with a partial standalone fixture. Meta-schema validation
uses that same complete context, including remote `$ref` and `$dynamicRef`.

Run all workload preflights and release measurements without fetching an external
corpus:

```bash
cd Benchmarks
swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark \
  --target JSONSchemaBenchmarks --no-progress
```

This is workload coverage for [#164](https://github.com/ajevans99/swift-json-schema/issues/164),
not evidence of an optimization. The following remain future issue work, **not
merge prerequisites for the benchmark-corpus change**:

- [ ] Profile at least two validation hot paths with Instruments and record findings.
- [ ] Implement a measured, correctness-preserving optimization exceeding 10% on a representative case.
- [ ] Publish repeated, same-environment before/after measurements and correctness results.

### Real-world JSONSchema corpus

Two **unmodified production schemas**, published by the OpenAPI Initiative, are
downloaded from `OAI/spec.openapis.org` at immutable commit
`c6bdb19b420e5666495fdc8bd473f8ba610a7913`:

| Benchmark source | Published schema | Size | License |
|------------------|------------------|------|---------|
| `openapi-3.1` | [OpenAPI 3.1, iteration 2025-11-23](https://raw.githubusercontent.com/OAI/spec.openapis.org/c6bdb19b420e5666495fdc8bd473f8ba610a7913/oas/3.1/schema/2025-11-23) | 33,452 B | Apache-2.0 |
| `overlay-1.0` | [Overlay 1.0, iteration 2026-04-01](https://raw.githubusercontent.com/OAI/spec.openapis.org/c6bdb19b420e5666495fdc8bd473f8ba610a7913/overlay/1.0/schema/2026-04-01) | 1,869 B | Apache-2.0 |

Both natively declare draft 2020-12. These are published JSON artifacts, not
development YAML, archived schemas, converted dialects, or a Sourcemeta subset.
Every `$ref` and `$dynamicRef` is local to its root; the fetcher checks the entire
schema-valued reference graph and rejects missing documents, pointers, or anchors.
OpenAPI's four dynamic references to local `#meta` are retained. `$schema` and
`jsonSchemaDialect.default` are not external instance-validation dependencies.
The loader supplies canonical `$id` URLs and a deterministic in-memory context;
there is no network lookup during construction or validation.

The small committed [manifest](./JSONSchemaBenchmarks/Resources/real-world-manifest.json)
pins every root and license artifact by immutable URL and SHA-256. It also records
attribution: **OpenAPI Specification, OpenAPI Initiative; Copyright The Linux
Foundation** (from the originating OpenAPI license at commit
`6c6c327036987ad18352478b5eba54be10e4865f`), and **Overlay Specification, OpenAPI
Initiative**. The publication repository's Apache-2.0 text is retained alongside
the originating OpenAPI license. Overlay's upstream license has a template
copyright placeholder; no specific holder or year is invented. The files remain
byte-for-byte unchanged, with license/attribution preserved in the resource bundle.

`fetch_schema_corpus.py` stages all four assets and publishes the directory only
after every checksum, JSON document, dialect, and reference passes validation.
On failure it leaves the previous cache untouched, not a partially new corpus.
Valid cached bytes are reused without network requests; corrupt cached bytes are
explicitly reported and replaced only by a verified download. To verify a cache
without network access:

```bash
python3 Benchmarks/Scripts/fetch_schema_corpus.py --offline
```

Absent downloads are optional for local runs; a partially present bundle is
always an error. `JSONSCHEMA_BENCHMARK_CORPUS=required` makes wholly absent
downloads an error too. Fetch or verify **before building** so SwiftPM bundles
the right resources. CI requires this mode and additionally checks the exact
discovered inventory: package-benchmark can return a successful listing exit
code even when a benchmark process crashes, so exit status alone is insufficient.

#### Generated workloads and runtime bounds

[`RealWorldInstances.swift`](./JSONSchemaBenchmarks/RealWorldInstances.swift)
generates deterministic instances outside measurement. Nothing large is committed
or generated into resource files. The default **PR subset** uses sizes **10 and
100**; `JSONSCHEMA_BENCHMARK_SIZES=extended` also includes **1000**.

| Source | Size means | `invalid-early` | `invalid-late` / `invalid-many` |
|--------|------------|-----------------|--------------------------------|
| OpenAPI | N path entries, each with an operation, parameter, and response; N tag objects | Wrong `/openapi` version pattern, full paths retained | Last / every response `description` is an integer instead of a string |
| Overlay | N distinct, item-validated action objects | Wrong `/overlay` version pattern, full actions retained | Last / every action `target` is an integer instead of a string |

`valid` traverses the entire generated structure. Early/late refer to **error
location**, not a promised fail-fast implementation; large early-invalid instances
are always paired with equally sized valid and late-invalid cases. The many-error
case checks first/last concrete leaf locations and at least N raw and rendered
leaf errors. All variants check expected validity and all four output formats
outside measurement, even when only selected output formats are timed.

OpenAPI's selected official schema explicitly **does not validate embedded Schema
Objects beyond their object/boolean type**; growth is in paths/operations/tags,
not arbitrary Schema Object contents. Overlay's `update` payload is unconstrained;
it stays small while the validated actions array grows. Neither root contains
`minLength`; negatives use actual type/pattern assertions, never invented
constraints. JSON Schema validation does not execute Overlay actions or resolve
instance-data operation links, and is not complete normative-spec conformance.

Each source adds one construction benchmark, four validation variants per size,
Basic output for size-10 valid, Verbose for size-10 late-invalid, and Basic/Verbose
for many-error cases at every size. Names include source, size, and validity,
for example `validate.openapi-3.1.100.invalid-late.Schema.validate`.

This adds **30 cases** in the PR subset (**96 JSONSchema / 160 combined** with
the full OrderedJSON corpus), or **42 cases** extended (**108 / 172 combined**).
All prior 66 JSONSchema and 64 OrderedJSON names are preserved. New cases use
one warmup and at most 20 measured iterations or one second per case, whichever
is reached first; preflight and an individual long operation can exceed that
duration. Original case configurations are unchanged. Extended cases are opt-in,
not required PR threshold inventory.

The complete 108-case extended JSONSchema release smoke run took **142.83 s**
on the development macOS ARM64 / Apple Swift 6.4 machine. This is one end-to-end
runtime observation (including build/setup), not an optimization comparison or a
promise about shared CI timing.

```bash
python3 Benchmarks/Scripts/fetch_schema_corpus.py
JSONSCHEMA_BENCHMARK_CORPUS=required JSONSCHEMA_BENCHMARK_SIZES=extended \
  swift package --package-path Benchmarks --disable-automatic-resolution \
  --allow-writing-to-package-directory benchmark --target JSONSchemaBenchmarks --no-progress
```

## Corpus

The OrderedJSON suite uses five committed files that cover the workload space without requiring external downloads:

| File | Size | Shape |
|------|------|-------|
| `small.json` | 8 B | Smallest possible object. Measures fixed parser overhead, not throughput. |
| `wide-object.json` | 1.9 KB | 100 string-keyed scalar properties. Stresses object key handling. |
| `deep-array.json` | 0.1 KB | 50 levels of nested arrays. Stresses recursion / depth tracking. |
| `poll-instance.json` | 0.7 KB | A real-world `Poll`-shaped instance. Mixed types, modest nesting. |
| `users-array.json` | 26 KB | 100 user records with metadata. Large-ish wide+nested mix. |

CI also fetches three established, multi-megabyte reference files:

| File | Size | Shape |
|------|------|-------|
| `canada.json` | 2.2 MB | Deeply nested coordinate arrays. |
| `citm_catalog.json` | 1.7 MB | Wide, schema-like catalog data. |
| `twitter.json` | 0.6 MB | String-heavy nested objects. |

They are not vendored because they would inflate every clone. The fetch script
pins both the upstream commit and each file checksum.

The JSONSchema suite retains the Poll, OpenAPI fragment, and complete draft
2020-12 meta-schema, and adds three bounded synthetic schemas for regex,
reference, and combinator workloads. All six include valid and invalid inputs.
The new focused fixtures are authored in this repository and require no downloads.

## Adding a new case

1. Drop a `.json` file into [`OrderedJSONBenchmarks/Resources/`](./OrderedJSONBenchmarks/Resources/).
2. Add its name to the `committedNames` array in [`OrderedJSONBenchmarks.swift`](./OrderedJSONBenchmarks/OrderedJSONBenchmarks.swift) (under `Corpus.load`).
3. Re-run `swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark` from the `Benchmarks/` directory.

The corresponding parse/serialize/roundtrip benchmarks are generated automatically.

For JSONSchema, add a schema plus valid/invalid instance resources and register
them in `SchemaCorpus.load()`. Declare expected validity and meaningful leaf-error
locations for invalid instances. Keep schema construction separate from the
instance list, then run the full JSONSchema suite to exercise its preflight checks.

## Baselines and CI

Committed p90 allocation thresholds live in [`Baselines/`](./Baselines/). Capture
and enforcement both select **only `mallocCountTotal`** so instrumentation is
identical; collecting clock/CPU metrics also allocates and is not an equivalent
allocation baseline. CI runs
both benchmark targets and the full reference corpus on `ubuntu-24.04`, writes
wall-clock / CPU / malloc tables to the GitHub Actions job summary, and checks
malloc counts against the committed thresholds.

Wall-clock and CPU values are informational on the shared GitHub-hosted runner.
Calibration runs of the same commit varied far beyond the initial 10% timing
tolerance, so treating static timing changes as a required check would be
flaky. Use the reported tables to spot trends and reproduce suspected timing
regressions on a dedicated runner. Allocation counts remain deterministic
enough to enforce with the configured 10% relative and 10-allocation absolute
tolerances.

When a new benchmark has no committed baseline yet, CI generates a complete
baseline artifact instead of performing a partial regression check. Commit the
artifact from the pinned runner; the next run enforces it.

CI sets `SWIFT_DETERMINISTIC_HASHING=1` for both capture and enforcement.
Random hash seeds change Foundation dictionary traversal and therefore the
comparison/allocation work of `.sortedKeys`, even for identical source bytes.
Fixed hashing makes that workload repeatable; it does not change library
defaults or establish performance across arbitrary hash seeds. Set the same
environment variable when reproducing thresholds locally. Timing remains
informational, including under fixed hashing.

To intentionally refresh an already complete set, dispatch the **Benchmarks**
workflow on the desired branch with `refresh_baselines=true`. This opt-in
artifact-generation run is named **Capture benchmark baselines**, skips
enforcement, and is not evidence of the **Package benchmarks** regression
check passing. Commit the unmodified artifact, then run the default workflow
(`refresh_baselines=false`) separately to enforce it. Pull-request runs use
the default checking path.

With complete coverage, JSONSchema reporting and enforcement also run when
OrderedJSON fails, unless the workflow is cancelled. The job still fails for
either suite's regression; this only preserves independent diagnostics.

The full PR corpus requires **160 thresholds**: 64 OrderedJSON, 66 original
JSONSchema workload cases, and 30 downloaded-schema cases. The workflow asserts
Swift 6.3.3 and requires the fetched corpus and the small/medium PR subset.
The workflow currently targets PRs into `main`, so a
draft targeting an intermediate stack branch may need an explicit workflow
dispatch or later final-base run to obtain that artifact. Timing and throughput
remain informational; the allocation-only guard is unchanged.

The preceding OrderedJSON layer's 82 fixed-hash thresholds were captured in [Ubuntu run 34719883609](https://github.com/ajevans99/swift-json-schema/actions/runs/34719883609)
at checkout `f424f3df8d309b65d480936928aa92b99195cae3` via an explicit
`workflow_dispatch` refresh, not a moving PR merge ref. That branch includes
main `15ab4569bf68b1c3a84a8ffdc008b100f5416ebf`; its production sources,
benchmark definitions, and dependency locks match the capture. The runner was `ubuntu-24.04`
(image `20260907.300.1`) with Swift 6.3.3, `x86_64-unknown-linux-gnu`.
The artifact is copied without adjusting counts. It refreshes the previous 66
cases as well as adding the new cases; all files now contain only
`mallocCountTotal`, matching enforcement. No macOS or emulated timing results
are used as thresholds. Timing and throughput remain informational, and the
10% relative / 10-allocation absolute tolerances are unchanged.

The earlier random-hash capture was superseded after independent hosted
checks both passed and failed on equivalent production code. For example,
the Poll Foundation round trip varied from 619 to 643 allocations, exceeding
the unchanged 10-allocation limit. The fixed-hash capture reports 599 for
Poll, 597,532 for CITM, and 556,393 for Twitter; these are workload counts,
not parser optimization gains. This capture-only run predates the distinct
capture job name and must not be mistaken for an enforcement result.

This refresh also incorporates newer correctness fixes, not just capture
overhead changes. In particular, [#195](https://github.com/ajevans99/swift-json-schema/pull/195)
isolates concurrent schema evaluations with fresh dynamic-scope frames and
task-local scope state. That has a real allocation cost in meta-schema
validation/output workloads; the correctness fix is retained, not classified
as runner noise or a performance improvement. The refresh spans other source
changes too, so it does not isolate or quantify the cost of #195 alone.

Baseline generation is only allowed after successful benchmark discovery.
Listing failures or empty/unrecognized listings fail CI without generating
replacement thresholds. Discovery, generation, and checks all disable automatic
dependency resolution. The coverage script exits with status 0 for complete
coverage, 1 for missing baseline files, and 2 for discovery errors.

Run the offline integrity, inventory, and CI regression cases from the repository root:

```bash
python3 Benchmarks/Scripts/test_schema_corpus.py
python3 Benchmarks/Scripts/test_baseline_coverage.py
```

To refresh baselines on the same runner class after an intentional improvement, run:

```bash
cd Benchmarks
export SWIFT_DETERMINISTIC_HASHING=1
rm -rf Baselines
swift package --disable-automatic-resolution --allow-writing-to-package-directory benchmark \
  thresholds update --metric mallocCountTotal --path Baselines --no-progress
```

Capture thresholds with the same allocation-only metric selection used by
enforcement. Enabling additional metrics during capture can change measurement
overhead and therefore the allocation count; timing still appears in the
separate informational report.

package-benchmark reports improvements through a SwiftPM plugin error marker;
the CI wrapper accepts only that marker. Regressions, missing baselines, and
other plugin failures still fail the job.

Benchmark numbers are runner-sensitive. Refresh committed baselines only from
the pinned CI runner or a matching environment, and include the reason in the
pull request.
