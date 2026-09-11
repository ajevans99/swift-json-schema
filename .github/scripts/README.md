# API compatibility checks

Both API workflows run `api-compatibility.py`. Run the offline regression tests with:

```sh
python3 -m unittest discover -s .github/scripts -p 'test_api_compatibility.py'
```

The tests use a mock `swift` executable and Python's standard library; no Swift
installation, dependencies, or network access is required. Both workflows also
run them before scanning.

## Result contract

The workflows use `macos-26` for Swift 6.2 or newer, avoiding the known Swift 6.1.2
digester issue described in the workflow. The parser follows SwiftPM 6.2's
[`APIDiff.run` and `printComparisonResult`](https://github.com/swiftlang/swift-package-manager/blob/swift-6.2-RELEASE/Sources/Commands/PackageCommands/APIDiff.swift)
and [`SwiftAPIDigester` / `apiDigesterModules`](https://github.com/swiftlang/swift-package-manager/blob/swift-6.2-RELEASE/Sources/Commands/Utilities/APIDigester.swift).
It has also been exercised with Apple Swift 6.4.

SwiftPM returns **0** for a clean scan, but **1 for both API breaks and failures**.
It can report valid breakages for one module alongside a failure in another.
Consequently, neither the exit status nor the presence of breakage lines alone
proves a completed scan.

The runner discovers the current package's Swift library product modules with
`swift package describe --type json` (including `OrderedJSON`, without a hardcoded
library list). It requires exactly one completion or explicit baseline-absence
record per expected module, at least one compared module, consistent finding
counts, and no non-API error diagnostics. Only exit 0 with no findings is `clean`;
only exit 1 with findings is `breaking`. Everything else is `failed` and exits 1.
Skipped new modules are disclosed rather than described as compared.

Output is deliberately version-sensitive and fails closed on missing or changed
completion formats, unsupported exit statuses, or ambiguous results. The runner
image is pinned, not an exact Swift patch release: review these checks and their
fixtures when updating the image/toolchain. This protects against incomplete
scans, not upstream digester false positives or limitations in the API it covers.
Module discovery follows SwiftPM's current/head library products, as the command
does; it does not add a separate check for completely removed products.

## Reporting and permissions

Completed breaking scans remain successful to allow intentional public API
changes. Failed scans report unknown compatibility, fail the job, and never
change the `breaking-change` label. The PR workflow updates the same sticky
comment even on scan failure, so a previous clean result does not remain current.
Fork and Dependabot PRs skip comment/label writes and use the summary and artifacts.

Both workflows always write a summary (with a failure fallback if the runner never
finishes) and upload `api-report.md`, discovery output, and the complete diagnostic
logs. Summaries include the last 500 log lines; artifacts retain the full output.
The release workflow reads tooling from the workflow revision in a separate
checkout, so selecting an older `head_ref` does not require that ref to contain
these scripts. Benchmark targets are in a separate package; no ineffective
`SKIP_BENCHMARKS` override is used.
