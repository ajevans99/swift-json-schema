# Validation output formats

Producing the four spec-defined validation output formats — Flag, Basic, Detailed, and Verbose.

## Overview

JSON Schema 2020-12 defines four standard output formats with progressively more detail. `JSONSchema` produces all four via ``ValidationResult/renderedOutput(level:)``.

```swift
let result = schema.validate(instance)
let basic = try result.renderedOutput(level: .basic)
```

The result is a ``OrderedJSON/JSONValue`` matching the spec's [Output Schema](https://github.com/json-schema-org/JSON-Schema-Test-Suite/blob/main/output-tests/draft2020-12/output-schema.json) for that level.

## Levels at a glance

### Flag

The minimal form: a single boolean indicating overall validity.

```json
{ "valid": false }
```

Use when you only need to gate a value on validity (e.g., reject a request) and don't care why it failed.

### Basic

A flat list of all errors and annotations. Each entry includes its keyword location, instance location, and either an error message or an annotation value.

```json
{
  "valid": false,
  "errors": [
    {
      "keywordLocation": "/properties/age/minimum",
      "instanceLocation": "/age",
      "error": "Validation failed."
    }
  ]
}
```

The default for human-facing tooling.

### Detailed

A hierarchical version of Basic. Errors are nested by their containing applicator (`allOf`, `anyOf`, etc.), so the structure mirrors the schema's logical shape.

```json
{
  "valid": false,
  "keywordLocation": "",
  "instanceLocation": "",
  "errors": [ { "keywordLocation": "/properties", ... } ]
}
```

Use when you want the *shape* of the validation tree, not just the leaves.

### Verbose

Every keyword that ran — pass or fail — appears in the tree, with full context for each.

```json
{
  "valid": false,
  "keywordLocation": "",
  "instanceLocation": "",
  "errors": [ /* every failed keyword */ ],
  "annotations": [ /* every annotation produced */ ]
}
```

Best for debugging: shows you exactly what each keyword did, even the ones that succeeded.

## Determinism

Output is fully deterministic across processes (see <doc:Deterministic-schema-output>). The order of `errors` and `annotations` arrays reflects the validation traversal order — itself driven by the instance's declared key order — so two invocations against the same schema/instance pair produce byte-identical output.

This is what makes snapshot testing of validation results practical (the package itself uses this in `PollExampleTests` and `MetaSchemaValidationTests`).

## Output configuration

For finer control, use ``ValidationOutputConfiguration`` directly:

```swift
let config = ValidationOutputConfiguration(level: .verbose)
let output = try result.renderedOutput(configuration: config)
```

Or call the convenience overload on `Schema`:

```swift
let output = try schema.validate(
  instance,
  output: ValidationOutputConfiguration(level: .verbose)
)
```

## Spec conformance

The implementation passes the official [Output Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite/tree/main/output-tests/draft2020-12) (`OutputTestSuite.swift` in the test target). If you find a spec-compliance gap, file an issue with the failing test case.
