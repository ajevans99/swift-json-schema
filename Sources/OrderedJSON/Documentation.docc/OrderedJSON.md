# ``OrderedJSON``

An order-preserving JSON parser, serializer, and value type for Swift.

## Overview

`OrderedJSON` is a small, RFC-8259-conformant library that handles JSON the way most humans expect: **the order you wrote keys in is the order they come out**. Foundation's `JSONDecoder` and `JSONEncoder` randomize object key order across processes (their `Dictionary`-backed storage is hash-seed dependent). `OrderedJSON` uses an `OrderedCollections.OrderedDictionary` internally and ships a custom serializer that walks values in insertion order.

It's the foundation of the deterministic-output story in [`JSONSchema`](https://swiftpackageindex.com/ajevans99/swift-json-schema), but it's also useful standalone — anywhere you need byte-stable JSON output (snapshot testing, signed payloads, reproducible artifacts), `OrderedJSON` is the right shape.

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
- ``JSONType``

### Parsing

- <doc:Parsing-JSON-deterministically>
- ``JSONValue/parse(_:)-7yr2v``
- ``JSONValue/parse(_:)-2hbu0``
- ``JSONParseError``

### Serializing

- <doc:Serializing-JSON>
- ``JSONValue/serialized(options:)``
- ``JSONValue/serializedData(options:)``
- ``JSONValue/SerializationOptions``
- ``JSONValue/NonConformingFloatStrategy``
- ``JSONValue/SerializationError``

### Comparison with Foundation

- <doc:Ordered-vs-Foundation>
