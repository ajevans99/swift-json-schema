# Validation output formats

Choose how much detail to include in your validation diagnostics.

## Overview

``ValidationResult/renderedOutput(level:)`` returns a JSON value suitable for displaying
or serializing diagnostics:

```swift
import JSONSchema

let schema = try Schema(
  rawSchema: [
    "type": "object",
    "properties": ["age": ["type": "integer", "minimum": 0]],
    "required": ["age"],
  ],
  context: Context(dialect: .draft2020_12)
)
let result = schema.validate(["age": -1])
let basic = try result.renderedOutput(level: .basic)
print(try basic.serialized(options: .pretty))
```

The basic output's leaf error includes `instanceLocation: "/age"` and
`keywordLocation: "/properties/age/minimum"`, so consumers can connect a failure to both
the input value and the rule that rejected it.

## Choose a level

| Level | Current output | Use it for |
| --- | --- | --- |
| `.flag` | A JSON boolean, such as `false`. | Checking validity without diagnostic detail. |
| `.basic` | A result object with flattened leaf errors and, for valid results, available annotations. | Form errors, logs, and other consumers that need direct failure locations. |
| `.detailed` | A result object with a condensed error tree. | Understanding failures through schema compositions without every intermediate node. |
| `.verbose` | A result object retaining the available nested error tree and annotations. | Debugging the structure of a validation result. |

These levels use the JSON Schema output terminology. The current flag renderer returns a
bare boolean, not a `{ "valid": false }` object. Verbose output renders the information stored
in ``ValidationResult``; it is not a separate trace of every successful keyword evaluation.

```swift
let flag = try result.renderedOutput(level: .flag) // JSONValue.boolean(false)
let verbose = try result.renderedOutput(level: .verbose)
```

## Output configuration

Use ``ValidationOutputConfiguration`` when passing the desired level through your application:

```swift
let config = ValidationOutputConfiguration(level: .basic)
let output = try schema.validate(["age": -1], output: config)
```

The configuration also works with `result.renderedOutput(configuration:)`.

## Serialization and ordering

Basic, detailed, and verbose output objects, including nested error objects, emit fields in
this order: `valid`, `keywordLocation`, `absoluteKeywordLocation`, `instanceLocation`,
`error`, `errors`, `annotations`. Absent optional fields are omitted. This core-fields-first
order aligns with the library's result representation rather than the alphabetical order
of the previous Foundation-based renderer. Direct serialization preserves this order;
annotation values retain their own stored property order.

The output renderers for basic, detailed, and verbose construct JSON values directly,
without a Foundation encoding/decoding round-trip. Numeric annotations retain their
`JSONNumberLiteral` values rather than passing through `Double`, including tokens such as
`1e1000` outside `Double` and `Decimal` range. Calling `renderedOutput(level:)` and then
`serialized` does not impose Foundation's numeric encoding limits. Those limits apply only
if you subsequently use a `Codable` encoding path, such as `JSONEncoder.encode`.

The rendered diagnostic structure is separate from ``ValidationResult/jsonValue``, which
exposes the library's ordered representation of the original result.

Numeric operands in ``ValidationIssue`` cases such as `exceedsMaximum` and `notMultipleOf`
use `JSONNumberLiteral`. When handling those issues directly, read `rawValue` for the numeric
token or use an explicit throwing conversion instead of assuming a `Double` payload.
Public error bound payloads for lengths, item counts, property counts, and `contains`
matches remain `Int`, as do actual counts and array indexes. These constraints compare exact
`JSONNumberLiteral` values and narrow bounds only when reporting a failed constraint. If a
failed bound cannot be represented as `Int`, `numericValidationFailure` reports the exact
bound in its reason instead of clamping it or substituting a default.

For reproducible serialization of that result, use:

```swift
let bytes = try result.jsonValue.serializedData(options: .pretty)
```

See <doc:Deterministic-schema-output> for input-order requirements and serialization guarantees.
