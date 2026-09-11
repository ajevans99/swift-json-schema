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

The output renderers for basic, detailed, and verbose currently bridge through Foundation
encoding and decoding. Do not rely on their returned object key order. Their diagnostic
structure is separate from ``ValidationResult/jsonValue``, which exposes the library's
ordered representation of the original result.

For reproducible serialization of that result, use:

```swift
let bytes = try result.jsonValue.serializedData(options: .pretty)
```

See <doc:Deterministic-schema-output> for input-order requirements and serialization guarantees.
