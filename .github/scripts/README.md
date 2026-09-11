# API compatibility checks

Run the offline regressions (Python standard library only):

```sh
python3 -m unittest discover -s .github/scripts -p 'test_api_compatibility.py'
```

Both API workflows capture Swift's exit status and full log, then use
`api-compatibility.py` to classify the result. SwiftPM returns **0** for clean
scans and **1 for both API breaks and failures**. Exit 1 is accepted only with
API findings and no error diagnostics; other nonzero statuses fail. Errors
override findings, including partial results from failed module comparisons.
Failed scans report unknown compatibility and never change the PR label.

This follows SwiftPM's
[`APIDiff`](https://github.com/swiftlang/swift-package-manager/blob/swift-6.2-RELEASE/Sources/Commands/PackageCommands/APIDiff.swift)
error reporting, verified on Swift 6.3.3 (macos-26) and 6.4. We rely on SwiftPM to
detect incomplete comparisons rather than duplicating its module inventory and
completion parsing. Recheck diagnostic/exit semantics when upgrading toolchains.
The release workflow checks out the classifier separately so older head refs
need not contain it. Full logs are retained as artifacts; summaries show 500 lines.
