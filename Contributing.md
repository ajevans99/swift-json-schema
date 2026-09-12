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

## Running Tests

Use Swift 6.1 or later. Initialize the conformance suites at their committed revisions before running tests:

```bash
git submodule update --init --recursive
swift test
```

The main package publishes libraries, not a demo executable. Add runnable examples and regressions to the existing test targets rather than a scratch client:

- `Tests/JSONSchemaBuilderTests/CompileTimeMacroTests.swift` checks that generated macro expansions compile.
- `Tests/JSONSchemaIntegrationTests/` exercises macros, parsing, validation, and conversions together.
- `DocumentationExampleTests.swift` files keep documentation examples executable.

To run just the integration tests:

```bash
swift test --filter JSONSchemaIntegrationTests
```

## Macro Architecture

The `@Schemable` implementation is a syntax-backed parse, plan, and emit pipeline:

| Location under `Sources/JSONSchemaMacro/Schemable/` | Responsibility |
| --- | --- |
| `SchemableMacro.swift` | Macro entry point and publication of diagnostics |
| `Parsing/` | Declaration, type, and option analysis, plus syntax helpers |
| `Planning/` | Schema and field plans, including field-selection and schema policies |
| `Emission/` | Rendering plans as SwiftSyntax declarations and expressions |
| `Diagnostics/` | Diagnostic collection and initializer/option validation |

These directories belong to one SwiftPM target, not separate modules. Small parser-specific diagnostic definitions stay beside the parsing code that produces them.

- `SchemableDeclaration` and `MacroConfiguration` parse declaration metadata and macro configuration. Declaration kind is retained: struct-only synthesized-initializer checks are not applied to classes. When no initializer is locally visible on a class, Swift resolves initialization rather than the macro guessing about inheritance or extensions.
- `SchemaType` normalizes supported Swift type spellings without generating code. Named types retain their full syntax, including generic arguments. This is syntax analysis, not type checking; aliases and conformance resolution remain the Swift compiler's responsibility.
- `ParsedOptions` parses option calls once, retaining source nodes, arguments, closures, and order for both diagnostics and generation.
- `SchemaPlanner` produces explicit included, excluded, and unsupported member/case plans. Initializer diagnostics consume the same included fields that emission uses. An unsupported enum payload invalidates the whole case instead of emitting a partial constructor.
- `FieldPlanner` resolves property keys, defaults, ordered schema replacements, requiredness, null representation, and reference requirements. Properties and enum payloads share field construction, but retain their distinct null-handling policies.
- `SchemaEmitter`, `FieldEmitter`, `TypeSchemaEmitter`, and `SchemaOptionsGenerator` render the plans. Only the macro adapter publishes collected diagnostics to `MacroExpansionContext`.

Keep policy decisions out of emitters and generated expressions out of type analysis. Add new syntax support to the type parser, new option interpretation to option parsing/planning, and new rendering behavior to the relevant emitter.

Option ordering is significant across attributes as well as within them: `.customSchema(...)` replaces the accumulated schema, discarding defaults and modifiers before it. Modifiers after it are retained. Preserve source order when combining general and type-specific options for both properties and declarations; do not regroup them by category. Property keys retain the precedence `.key(...)`, `CodingKeys`, `keyStrategy`, then the Swift property name. An explicit `keyStrategy: nil` is normalized to an absent strategy. Every recognized type-specific option group participates in both diagnostics and emission.

Access control is normalized for protocol witnesses: `open` declarations emit `public` witnesses, `private` declarations emit `fileprivate` witnesses, and conformance extensions have no explicit access modifier. Non-access modifiers such as `final` and `indirect` are never copied onto schema properties.

Configuration requiring compile-time interpretation (`optionalNulls` and composition choices) must use explicit literals/cases. Nonliteral configuration and unrecognized option syntax produce diagnostics rather than silently selecting defaults or dropping options. Included stored properties require explicit type annotations. Unsupported property types retain their warning-and-exclusion behavior; unsupported enum payloads produce errors.

Use focused type-analysis and planning tests for policy, expansion tests for emitted source and diagnostics, and compile-time/integration fixtures for generated-code validity and parsing behavior. In particular, cover equivalent optional/collection spellings, named generics, constructor field selection, option replacement order, and recursive reference requirements.

## Code Formatting

All code must be formatted using Swift format to ensure consistency across the codebase. The CI pipeline will check for formatting issues automatically. You can add the `auto-format` label to your pull requests to enable automatic Swift formatting before merging.

### How to Use

1. Create a pull request as usual.
2. Add the `auto-format` label to your pull request.

When the label is added, the CI pipeline will automatically format the code and commit the changes to your pull request.

For more information about Swift format, visit the [Swift format repository](https://github.com/apple/swift-format).
