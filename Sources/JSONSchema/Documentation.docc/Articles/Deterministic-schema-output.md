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

The same input yields identical bytes on every run, every process, every platform — no `JSONEncoder.outputFormatting = [.sortedKeys]` workaround required.

## Key order

For object schemas, ``Schema/jsonValue`` walks the schema's keywords in **dialect-registration order** (the same order ``Schema/encode(to:)`` uses internally). That means `$id` consistently appears before `type`, regardless of the order they were declared in the source.

This is intentional. JSON object keys are unordered for *equality*, but a stable, predictable emission order makes:

- Snapshot tests of generated schemas don't flake
- Diff-friendly logs of validation results
- Signed/hashed JSON payloads that downstream consumers can verify
- Generated artifacts (TypeScript types, OpenAPI specs, etc.) that don't churn between runs

## Why not `Codable`?

`Schema` still conforms to `Codable` — `JSONEncoder().encode(schema)` works. But the `JSONEncoder` keyed-container API stores keys in a `Dictionary` internally, dropping any insertion order along the way. Without `[.sortedKeys]`, output ordering is hash-seed dependent (varies across processes); with `[.sortedKeys]`, output is alphabetical, which is its own kind of arbitrary.

The ``Schema/jsonValue`` accessor sidesteps both problems by walking the schema's keyword list in declared-dialect order and building the result directly into an ``OrderedCollections/OrderedDictionary``. No serialization round-trip.

See [issue #149](https://github.com/ajevans99/swift-json-schema/issues/149) for the full background on why determinism mattered enough to warrant a custom serializer.

## Validation results

The same story applies to ``ValidationResult/jsonValue``:

```swift
let result = schema.validate(.string(""))
let bytes = try result.jsonValue.serialized(options: .pretty)
```

The `valid`, `keywordLocation`, `absoluteKeywordLocation`, `instanceLocation`, `errors`, `annotations` field order matches the existing `Codable` contract. Each ``ValidationError`` and annotation inside the tree is similarly order-stable.
