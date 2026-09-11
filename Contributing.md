## Introduction

Welcome to Swift JSON Schema! Contributions are welcome and greatly appreciated. By contributing, you are helping to make this project better for everyone.

## Linux Testing

Linux CI runs the full suite, including macro expansion and integration snapshots, in the `swift:6.3.3-noble` container. This pin defines the CI test environment, not a new package minimum.

The tested dependency resolution includes SwiftSyntax 601.0.1, built from source with this compiler. CI enforces `Package.resolved` and exercises macro compilation and expansion rather than assuming compiler and SwiftSyntax release numbers must match. Changing to Swift 6.1 or SwiftSyntax 603 is not an isolated CI adjustment: the locked Collections version requires Swift 6.2, and the locked SnapshotTesting version constrains SwiftSyntax to versions below 602.

Python 3 must be on `PATH`: the pinned JSON Schema test suite's `bin/jsonschema_suite remotes` helper uses it to load remote-reference fixtures. This command only needs the Python standard library, not a running HTTP server or third-party Python packages.

To reproduce Linux CI, initialize the committed fixture submodules and run these commands in that container from the repository root:

```sh
apt-get update
apt-get install -y --no-install-recommends python3
swift test --jobs 2 --force-resolved-versions
```

Keep `Package.resolved` and the fixture revisions intact; do not update them just to run tests. `--force-resolved-versions` fails instead of resolving a different dependency set. When bind-mounting a checkout that also builds on macOS, add `--scratch-path .build/linux` to the test command to isolate Linux build artifacts.

## Style Guidelines

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
- Write clear and concise comments where necessary.
- Ensure your code is well-documented and includes meaningful test cases.

## Code Formatting

All code must be formatted using Swift format to ensure consistency across the codebase. The CI pipeline will check for formatting issues automatically. You can add the `auto-format` label to your pull requests to enable automatic Swift formatting before merging.

### How to Use

1. Create a pull request as usual.
2. Add the `auto-format` label to your pull request.

When the label is added, the CI pipeline will automatically format the code and commit the changes to your pull request.

For more information about Swift format, visit the [Swift format repository](https://github.com/apple/swift-format).
