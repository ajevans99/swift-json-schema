# Serializing JSON

Producing byte-stable JSON output from a ``JSONValue`` via ``JSONValue/serialized(options:)``.

## Overview

`OrderedJSON` ships its own serializer because Foundation's `JSONEncoder` doesn't preserve key order — even when the underlying `JSONValue` does. The keyed-container API in `JSONEncoder` walks an internal `Dictionary` keyed on `CodingKey`, dropping any insertion order along the way. `OrderedJSON.JSONValue.serialized(options:)` walks the value tree directly and emits keys in the order they're stored in the underlying ``OrderedCollections/OrderedDictionary``.

```swift
import OrderedJSON

let value: JSONValue = [
  "name": "Ada",
  "age": 37,
]

let compact = try value.serialized()
// → {"name":"Ada","age":37}

let pretty = try value.serialized(options: .pretty)
// → {
//     "name" : "Ada",
//     "age" : 37
//   }

let bytes = try value.serializedData()  // UTF-8 Data, same content
```

## Options

``JSONValue/SerializationOptions`` controls formatting:

- `prettyPrinted` — emit with line breaks and indentation, or compact on one line. Defaults to compact.
- `indent` — the indent string used per nesting level when pretty-printed. Defaults to two spaces.

Two convenience presets:

```swift
.compact     // SerializationOptions(prettyPrinted: false)
.pretty      // SerializationOptions(prettyPrinted: true)
```

## Number spelling and invalid numbers

Numbers are emitted from their validated `JSONNumberLiteral.rawValue`, without conversion
through `Int`, `Double`, or Foundation `Decimal`:

```swift
let value = try JSONValue.parse("[9.270,-0,1e1000]")
print(try value.serialized()) // [9.270,-0,1e1000]
```

Plain JSON has no representation for `NaN` or `±Infinity`. Invalid numbers are rejected when
constructed, not during serialization. The `.number(Double)` convenience factory has a
finite-value precondition. For an untrusted `Double`, use the throwing initializer:

```swift
func jsonNumber(from value: Double) throws -> JSONValue {
  .numberLiteral(try JSONNumberLiteral(value))
}
```

`NonConformingFloatStrategy`, `SerializationError`, and the `nonConformingFloatStrategy`
option have been removed. If your application needs a null or string sentinel, choose it
explicitly before constructing the JSON value. See <doc:Migrating-to-lossless-numbers>.

## Equality vs. ordering

`JSONValue.Equatable` is **order-insensitive** for objects (matching the JSON spec), but ordering is preserved for emission. This means:

```swift
let a: JSONValue = ["x": 1, "y": 2]
let b: JSONValue = ["y": 2, "x": 1]

a == b                    // true (objects compare by membership)
try a.serialized() != try b.serialized()
                          // true ({"x":1,"y":2} ≠ {"y":2,"x":1})
```

That's deliberate — JSON object semantics are unordered, but real-world consumers (snapshot tests, signed payloads, code review diffs) care a lot about which order the bytes come out in. `OrderedJSON` lets you have both.

Numbers also compare by mathematical value, not spelling. `1`, `1.0`, and `1e0` compare equal
and hash equally, but serialize to their stored tokens. Deterministic serialization is not
canonicalization.
