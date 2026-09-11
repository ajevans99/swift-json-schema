# Deterministic schema output

Producing byte-stable JSON from a ``Schema`` or ``ValidationResult`` without `JSONEncoder` round-trips.

## Overview

`JSONSchema` exposes direct ``Schema/jsonValue`` and ``ValidationResult/jsonValue`` accessors that return an `OrderedJSON.JSONValue` representation in deterministic, dialect-driven key order. Pair them with `JSONValue.serialized(options:)` to emit byte-stable JSON across processes and platforms.

```swift
let schema = try Schema(
  rawSchema: ["$id": "https://example.com/s", "type": "string", "minLength": 1],
  context: Context(dialect: .draft2020_12)
)

let json = schema.jsonValue                    // OrderedJSON.JSONValue
let pretty = try json.serialized(options: .pretty)
// → {
//     "$id" : "https://example.com/s",
//     "type" : "string",
//     "minLength" : 1
//   }

// Or get the UTF-8 bytes directly:
let bytes = try json.serializedData(options: .pretty)
```

For the same ordered input values and serialization options, the direct serializer emits
reproducible output without `JSONEncoder.outputFormatting = [.sortedKeys]`.

## Keep input order intact

Determinism depends on the input path as well as the serializer. Construct values with ordered
JSON literals/builders, or use `JSONValue.parse` for JSON text:

```swift
let schemaText = #"{"type":"object","properties":{"name":{"type":"string"}}}"#
let payloadText = #"{"name":"Ada"}"#
let parsedSchema = try Schema(
  rawSchema: JSONValue.parse(schemaText),
  context: Context(dialect: .draft2020_12)
)
let result = parsedSchema.validate(try JSONValue.parse(payloadText))
let output = try result.jsonValue.serialized()
```

The convenience `Schema(instance:)` initializer and builder `parse(instance:)` /
`parseAndValidate(instance:)` overloads use `JSONDecoder` by default. Once source key order
has been lost through a Foundation decoder or an unordered dictionary, the serializer cannot
recover it.

## Key order

For object schemas, ``Schema/jsonValue`` walks the schema's keywords in **dialect-registration order** (the same order ``Schema/encode(to:)`` uses internally). That means `$id` consistently appears before `type`, regardless of the order they were declared in the source.

This is intentional. JSON object keys are unordered for *equality*, but stable emission order helps with:

- Snapshot tests of generated schemas
- Diff-friendly logs of validation results
- Reproducible generated schema artifacts

Reproducible serialization is not a lossless round-trip of the original source text or a
canonicalization standard for signatures. Whitespace, escape sequences, and number spellings
can change. Equivalent objects with different stored property orders can emit different bytes;
schema keyword ordering and instance property ordering are also distinct.

## Why not `Codable`?

`Schema` still conforms to `Codable` — `JSONEncoder().encode(schema)` works. But the `JSONEncoder` keyed-container API stores keys in a `Dictionary` internally, dropping any insertion order along the way. Without `[.sortedKeys]`, output ordering is hash-seed dependent (varies across processes); with `[.sortedKeys]`, output is alphabetical, which is its own kind of arbitrary.

The ``Schema/jsonValue`` accessor sidesteps both problems by walking the schema's keyword list in declared-dialect order and building the result directly into an `OrderedCollections.OrderedDictionary`. No serialization round-trip.

See [issue #149](https://github.com/ajevans99/swift-json-schema/issues/149) for the full background on why determinism mattered enough to warrant a custom serializer.

## Validation results

Use ``ValidationResult/jsonValue`` for the ordered representation of a validation result:

```swift
let result = schema.validate(.string(""))
let bytes = try result.jsonValue.serialized(options: .pretty)
```

The `valid`, `keywordLocation`, `absoluteKeywordLocation`, `instanceLocation`, `errors`, `annotations` field order follows the library's result representation. Each ``ValidationError`` and annotation inside the tree is similarly ordered.

This accessor is distinct from `renderedOutput(level:)`, whose basic, detailed, and verbose
renderers currently bridge through Foundation. See <doc:Validation-output-formats> to choose
between diagnostic output shapes and the direct ordered representation.
