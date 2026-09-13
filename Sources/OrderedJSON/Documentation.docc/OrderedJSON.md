# ``OrderedJSON``

An order-preserving JSON parser, serializer, and value type for Swift.

## Overview

`OrderedJSON` provides a JSON value tree, parser, and serializer that preserve object key order
and JSON number tokens without converting them through `Double`.
It uses an `OrderedCollections.OrderedDictionary` internally and emits values in insertion order.
Foundation's `JSONDecoder` and `JSONEncoder` remain useful for `Codable` interoperability, but
do not guarantee preservation of that order, number spelling, or original numeric precision.

Use it independently for snapshot tests, ordered configuration files, and reproducible JSON
artifacts, or through [`JSONSchema`](https://swiftpackageindex.com/ajevans99/swift-json-schema).
Deterministic serialization is not source-text preservation or JSON canonicalization; see
<doc:Ordered-vs-Foundation> for the distinction.

```swift
import OrderedJSON

let value: JSONValue = [
  "$id": "https://example.com/schema",
  "type": "object",
  "properties": [
    "name": ["type": "string"],
    "age": ["type": "integer"],
  ],
]

// Same input → same bytes, every time, every process, every platform.
let bytes = try value.serializedData()
```

## Topics

### The value type

- ``JSONValue``
- ``JSONNumberLiteral``
- ``JSONType``

### Exact numbers

- <doc:Migrating-to-lossless-numbers>

### Parsing

- <doc:Parsing-JSON-deterministically>
- ``JSONValue/parse(_:)-(Data)``
- ``JSONValue/parse(_:)-(String)``
- ``JSONParseError``

### Serializing

- <doc:Serializing-JSON>
- ``JSONValue/serialized(options:)``
- ``JSONValue/serializedData(options:)``
- ``JSONValue/SerializationOptions``

### Comparison with Foundation

- <doc:Ordered-vs-Foundation>
