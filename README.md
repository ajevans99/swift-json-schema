# Swift JSON Schema

[![CI](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/ajevans99/swift-json-schema)](https://github.com/ajevans99/swift-json-schema/releases/latest)
[![SPI Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fswift-json-schema%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ajevans99/swift-json-schema)
[![SPI Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fswift-json-schema%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ajevans99/swift-json-schema)
[![Supported Dialects](https://img.shields.io/endpoint?url=https%3A%2F%2Fbowtie.report%2Fbadges%2Fswift-swift-json-schema%2Fsupported_versions.json)](https://bowtie.report/#/implementations/swift-swift-json-schema)
[![Draft 2020-12](https://img.shields.io/endpoint?url=https%3A%2F%2Fbowtie.report%2Fbadges%2Fswift-swift-json-schema%2Fcompliance%2Fdraft2020-12.json)](https://bowtie.report/#/implementations/swift-swift-json-schema)
[![codecov](https://codecov.io/gh/ajevans99/swift-json-schema/graph/badge.svg?token=P5CGW5A95K)](https://codecov.io/gh/ajevans99/swift-json-schema)

Generate JSON Schema from Swift types, validate JSON against Draft 2020-12 schemas, and parse validated input into typed Swift values.

Use the `@Schemable` macro or a composable result-builder DSL to define your schemas, or load existing schema documents with the standalone validator. The package also provides structured validation diagnostics, Foundation type conversions, and deterministic JSON serialization.

[Try the live playground](https://ajevans99.github.io/swift-json-schema-playground/) · [Documentation](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder) · [Latest release](https://github.com/ajevans99/swift-json-schema/releases/latest)

## Quick start

Define a model once, then use its schema to generate JSON Schema, parse valid input, and reject invalid data:

```swift
import JSONSchemaBuilder

@Schemable
struct Person {
  @StringOptions(.minLength(1))
  let name: String

  @NumberOptions(.minimum(0))
  let age: Int
}

let schema = Person.schema.definition()
print(try schema.jsonValue.serialized(options: .pretty))

let person: Person = try Person.schema.parseAndValidate(
  instance: #"{"name": "Ada", "age": 37}"#
)
print(person.name) // Ada

let result = schema.validate(["name": "Ada", "age": -1])
print(result.isValid) // false
```

`parseAndValidate` checks the schema's constraints and returns your Swift type, or throws with parsing and validation details. Use `schema.validate` when you only need a validation result, without constructing a model. [Learn about parsing and validation](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder/validation).

### Build schemas directly

Result builders infer their output types from the properties you declare:

```swift
let personSchema = JSONObject {
  JSONProperty(key: "name") {
    JSONString().minLength(1)
  }
  .required()

  JSONProperty(key: "age") {
    JSONInteger().minimum(0)
  }
  .required()
}

let parsed: (String, Int) = try personSchema.parseAndValidate(
  instance: #"{"name": "Ada", "age": 37}"#
)
```

The output is a tuple in property declaration order. `parseAndValidate` returns it directly; `parse` returns `Parsed<(String, Int), ParseIssue>`. Add `.map(Person.init)` to the builder to construct a `Person` instead.

Builders also support arrays, schema compositions, references, and conditional rules. [Explore the DSL](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder).

### Validate an existing schema

No Swift model or macro is required when your schema already exists:

```swift
import JSONSchema

let externalSchema = try Schema(
  instance: #"{"type": "string", "minLength": 3}"#
)
let validation = try externalSchema.validate(instance: #""hi""#)
print(validation.isValid) // false

let diagnostics = try validation.renderedOutput(level: .basic)
print(try diagnostics.serialized(options: .pretty))
```

The diagnostics identify the failing keyword and input location. [Learn about validation output](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema/validation-output-formats).

## Installation

Add the package in Xcode with **File > Add Package Dependencies**, or add it to `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/ajevans99/swift-json-schema", from: "0.13.2")
]
```

`from:` sets a minimum version and allows compatible updates; it does not pin an exact release. See the [latest release](https://github.com/ajevans99/swift-json-schema/releases/latest) for the current version.

Choose the products your target uses. For the quick start:

```swift
targets: [
  .target(
    name: "YourTarget",
    dependencies: [
      .product(name: "JSONSchemaBuilder", package: "swift-json-schema")
    ]
  )
]
```

| Library | Use it for |
|---------|------------|
| [`JSONSchema`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema) | Loading and validating existing JSON Schema documents, references, formats, and diagnostics. Re-exports `OrderedJSON`. |
| [`JSONSchemaBuilder`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder) | Generating schemas and parsing typed values with result builders and `@Schemable`. Builds on `JSONSchema`. |
| [`JSONSchemaConversion`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemaconversion) | Converting schema-defined strings into `UUID`, `URL`, and `Date` values. Builds on `JSONSchemaBuilder`. |
| [`OrderedJSON`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/orderedjson) | Order-preserving JSON parsing and serialization, independently of schema validation. |

**Requirements:** Swift 6.1 or later. Package deployment minimums are macOS 13, iOS 16, Mac Catalyst 16, watchOS 9, tvOS 16, and visionOS 1. Generated schemas and variadic object builders require macOS 14, iOS 17, Mac Catalyst 17, watchOS 10, or tvOS 17 on those platforms. The package also builds on Linux.

## Schema-first code generation

Starting with JSON Schema rather than Swift? The companion [swift-json-schema-codegen](https://github.com/ajevans99/swift-json-schema-codegen) package generates typed builder components from schema documents, completing the other direction: **JSON Schema to Swift**.

With its separate `JSONSchemaCodegen` product installed, an inline schema becomes a typed parser:

```swift
import JSONSchemaCodegen

@Schema("""
{
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "age": { "type": "integer", "minimum": 0 }
  },
  "required": ["name", "age"]
}
""")
enum PersonSchema {}

let person = try PersonSchema.schema.parseAndValidate(
  instance: #"{"name": "Ada", "age": 37}"#
)
print(person.name) // Ada
```

The output fields are inferred from the schema; you do not repeat their Swift types. A CLI and SwiftPM build-tool plugin also generate components from schema files, useful for shared API contracts, configuration formats, and design tokens. See the [codegen guide](https://github.com/ajevans99/swift-json-schema-codegen#readme) for installation, supported schemas, and file-based workflows.

## Explore the capabilities

The guides on Swift Package Index cover the details without requiring you to read generated macro code:

| Guide | What you can do |
|-------|-----------------|
| [Generate schemas from Swift types](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder/macros) | Model nested and recursive data, enums, collections, custom coding keys, and nullable properties. |
| [Build schemas manually](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder) | Compose reusable schemas with result builders, references, and dynamic object properties. |
| [Model conditional rules](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder/conditionalvalidation) | Express property dependencies and `if`/`then`/`else` validation. |
| [Parse into Swift values](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder/validation) | Combine parsing and validation, map outputs, and select composition branches. |
| [Validate existing schemas](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema) | Load schema documents, resolve references, and enable built-in or custom formats. |
| [Inspect validation output](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema/validation-output-formats) | Choose flag, basic, detailed, or verbose diagnostics. |
| [Convert Foundation types](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemaconversion) | Parse UUIDs, URLs, and dates using custom property schemas. |
| [Emit deterministic JSON](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema/deterministic-schema-output) | Produce reproducible schemas and validation results, and understand the serialization guarantees. |

## Ecosystem and integrations

- [swift-json-schema-playground](https://github.com/ajevans99/swift-json-schema-playground) ([live demo](https://ajevans99.github.io/swift-json-schema-playground/)) - an in-browser validation playground running the package as WebAssembly via SwiftWasm.
- [swift-mcp-toolkit](https://github.com/ajevans99/swift-mcp-toolkit) - strongly typed tools built on the official Model Context Protocol Swift SDK.
- [SwiftFunctionToolsExperiment](https://github.com/ajevans99/SwiftFunctionToolsExperiment) - type-safe OpenAI API function tool calls using schemas built with this library.
- [Bowtie](https://bowtie.report/#/implementations/swift-swift-json-schema) - cross-language JSON Schema conformance reports, with a dedicated [Swift harness](https://github.com/bowtie-json-schema/swift-swift-json-schema).
- [A2UI](https://github.com/a2ui-project/a2ui) - agent-generated user interfaces, with Swift core and component-catalog libraries that use this package.

Have a project to share? Open a PR to add it here.

## License

Released under the MIT license. See [LICENSE](LICENSE) for details.
