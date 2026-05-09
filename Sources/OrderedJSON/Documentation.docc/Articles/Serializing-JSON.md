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

``JSONValue/SerializationOptions`` controls three things:

- `prettyPrinted` — emit with line breaks and indentation, or compact on one line. Defaults to compact.
- `indent` — the indent string used per nesting level when pretty-printed. Defaults to two spaces.
- `nonConformingFloatStrategy` — how to handle `NaN` / `+Inf` / `-Inf`, which JSON cannot represent. See below.

Two convenience presets:

```swift
.compact     // SerializationOptions(prettyPrinted: false)
.pretty      // SerializationOptions(prettyPrinted: true)
```

## Non-finite floats

Plain JSON has no representation for `NaN` or `±Infinity`. ``JSONValue/NonConformingFloatStrategy`` mirrors `JSONEncoder.NonConformingFloatEncodingStrategy`:

```swift
case `throw`
case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
case null
```

The default is `.throw` — if the parser ever encounters a non-finite double, it throws ``JSONValue/SerializationError/nonConformingFloat(_:)`` rather than emitting invalid JSON.

```swift
let value: JSONValue = .number(.infinity)

// Default behavior — throws:
_ = try value.serialized()  // throws SerializationError.nonConformingFloat(.infinity)

// Explicit string substitution:
let opts = JSONValue.SerializationOptions(
  nonConformingFloatStrategy: .convertToString(
    positiveInfinity: "+Infinity",
    negativeInfinity: "-Infinity",
    nan: "NaN"
  )
)
try value.serialized(options: opts)  // → "+Infinity"
```

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
