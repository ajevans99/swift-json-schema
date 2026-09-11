## Introduction

Welcome to Swift JSON Schema! Contributions are welcome and greatly appreciated. By contributing, you are helping to make this project better for everyone.

## Running Tests

Initialize the conformance fixtures at their committed submodule revisions, then run the full package suite:

```sh
git submodule update --init --recursive
swift test --jobs 2
```

Python 3 must be on `PATH`: the pinned JSON Schema test suite's `bin/jsonschema_suite remotes` helper uses it to load remote-reference fixtures. This command only needs the Python standard library, not a running HTTP server or third-party Python packages.

Linux CI runs the full suite, including macro expansion and integration snapshots, in the `swift:6.3.3-noble` container with Python 3 installed. This pin defines the CI test environment, not a new package minimum. Keep `Package.resolved` and the fixture revisions intact when reproducing CI; do not update them just to run tests.

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
