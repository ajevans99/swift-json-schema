# Ordered vs. Foundation

Choose a JSON API based on your data model, ordering, and numeric-precision requirements.

## Overview

Foundation's `JSONDecoder` and `JSONEncoder` map JSON to and from `Codable` Swift types.
`JSONSerialization` works with untyped Foundation objects. `OrderedJSON` provides a
`JSONValue` tree with explicit object ordering and its own parser and serializer.

These APIs serve different purposes; schema validation does not require replacing every
use of Foundation JSON in your application.

| Capability | `JSONDecoder` / `JSONEncoder` | `JSONSerialization` | `OrderedJSON` |
| --- | --- | --- | --- |
| Direct conversion to custom `Codable` models | Yes | No | No; parses into `JSONValue` |
| Untyped JSON tree | Requires a value type such as `JSONValue` | Foundation objects, commonly accessed through `Any` | `JSONValue` |
| Source object order retained for later emission | Not guaranteed | Do not rely on dictionary iteration order across platforms | Preserved by `JSONValue.parse` |
| Serialization order | Unspecified by default; `.sortedKeys` sorts keys | Unspecified by default; `.sortedKeys` sorts keys | Stored insertion order |
| Original number tokens retained | No | No | Yes, through `JSONValue.parse` and `serialized` |
| Numbers beyond `Double` or `Decimal` range | Not guaranteed | Not guaranteed | Stored without conversion to those types |
| Original whitespace and string escape spelling retained | No | No | No |

Foundation implementations can differ across OS releases and platforms. Sorting keys can
provide predictable output, but it is not the same as preserving source or declaration order.

## Use Foundation for Codable models

If you already have `Codable` models and do not need insertion-order JSON output, continue
using `JSONDecoder` and `JSONEncoder`. `JSONValue` also conforms to `Codable` for interoperability,
but passing it through these APIs does not preserve its ordering or number-token guarantees.

`JSONNumberLiteral` also conforms to `Codable`. Foundation's `JSONEncoder` encodes the
standalone literal as a JSON number, not as a string or an object containing `rawValue`.

Numeric encoding tries `Int`, then `Double` only when constructing a `JSONNumberLiteral`
from that double equals the original value, then an exact `Decimal`. Otherwise it throws
`EncodingError` rather than silently rounding. Even successful encoding can change spelling,
such as emitting `1` for `1.0`.

Numeric decoding prefers `Decimal` and uses a decoded `Int` only when it agrees with that
decimal. This avoids accepting large fractional numbers as integers after binary rounding.
If the decoder cannot provide a decimal, it tries `Int`, then `Double`.
A generic `Decoder` does not expose raw JSON tokens, and Foundation may already have rounded
a value before the library receives it. Decoding therefore cannot promise original precision.
`OrderedJSON` does not provide a
replacement general-purpose `Codable` encoder or decoder.

For schema-driven conversion into Swift models, use the separate
[`JSONSchemaBuilder`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder)
library and its `parseAndValidate` API.

## Use OrderedJSON for ordered value trees

```swift
import OrderedJSON

let source = #"{ "name": "Ada", "age": 37 }"#
let value = try JSONValue.parse(source)
let compact = try value.serialized()
// {"name":"Ada","age":37}
```

The property order is retained, but the source whitespace is not. Number tokens retain their
original spelling, while string escapes can change. Objects with the same members in different
orders compare equal, yet can serialize differently. Likewise, numerically equivalent tokens
such as `1` and `1.0` compare equal without sharing the same serialized bytes.

This makes `OrderedJSON` useful for diff-friendly schema artifacts, snapshot tests, and
ordered configuration output. It is not a JSON canonicalization implementation: applications
that sign data must define their own byte representation or use their required canonical format.

Construct ordered values directly or parse with `JSONValue.parse`. Converting an existing
unordered Swift dictionary cannot recover the original source order.

## Performance

Benchmark the API that matches your workload rather than assuming ordering implies a
performance advantage. Foundation and `OrderedJSON` make different representation tradeoffs.
The repository's [benchmark guide](https://github.com/ajevans99/swift-json-schema/blob/main/Benchmarks/README.md)
describes the parser and serializer benchmarks.

The Foundation `JSONValue` benchmarks now retain decimal precision that the previous
`Int`/`Double` representation discarded. Their numeric work is therefore not equivalent
to the old baseline: a token such as `-65.613616999999977` must not silently become
`-65.61361699999998`. Exact `Decimal` conversion and Foundation's decimal formatting
can cost more than binary floating-point conversion, particularly on Linux.

## See also

- <doc:Parsing-JSON-deterministically>
- <doc:Serializing-JSON>
- <doc:Migrating-to-lossless-numbers>
