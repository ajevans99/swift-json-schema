# Parsing JSON deterministically

How `OrderedJSON.JSONValue.parse(_:)` differs from Foundation's parsers and what it guarantees.

## Overview

The parser conforms to [RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259) and the [nst/JSONTestSuite](https://github.com/nst/JSONTestSuite) reference cases. Unlike `JSONDecoder` — which randomizes object key order across processes — every parsed object preserves the order keys appear in the source bytes.

```swift
import OrderedJSON

let json = #"{"$id":"x","type":"object","properties":{"a":1,"b":2}}"#
let value = try JSONValue.parse(json)

// `value` retains $id → type → properties order, and inside properties,
// a → b order. Re-emitting via .serialized(options:) produces identical
// bytes, even from a different process.
```

## What gets accepted

- **Top-level scalars** (`null`, booleans, numbers, strings) — per RFC 8259's 2017 erratum, which made fragments part of the standard. Equivalent to passing `JSONSerialization.allowFragments`.
- **Numbers** decode as ``JSONValue/integer(_:)`` when they fit `Int` and have no fractional or exponent component, otherwise as ``JSONValue/number(_:)``.
- **Duplicate keys** are accepted; the **last** occurrence wins on both *value* and *position* — the late-bound key occupies the trailing position in the resulting object.
- **UTF-16 surrogate pairs in `\u` escapes** are decoded into single Unicode scalars.
- **The byte stream must be valid UTF-8**. UTF-16 / UTF-32 / BOMs are rejected.

## Limits

The parser caps nested object/array depth at **256 levels**. Deeper input throws ``JSONParseError`` rather than risking a stack overflow. For real-world JSON, 256 is far beyond what any sane producer emits — most reach 5–10 levels.

## Error reporting

``JSONParseError`` carries:

- `byteOffset` — 0-based UTF-8 byte index where the parser gave up
- `line` — 1-based line number; both `\n` and `\r\n` advance the counter
- `column` — 1-based UTF-8 byte column (not Unicode scalars or grapheme clusters; matches `byteOffset`'s units)

```swift
do {
  _ = try JSONValue.parse(badJSON)
} catch let error as JSONParseError {
  print("\(error.line):\(error.column): \(error.message)")
}
```

## When to use this vs `JSONDecoder`

| Need | Use |
|------|-----|
| Strongly-typed Swift model from JSON | `JSONDecoder` |
| Untyped JSON tree, key-order-preserving | `OrderedJSON.JSONValue.parse` |
| RFC-8259-strict parsing (no trailing commas, no comments) | `OrderedJSON.JSONValue.parse` |
| Round-trip byte-stable JSON (parse → emit → parse → emit) | `OrderedJSON.JSONValue.parse` + ``JSONValue/serialized(options:)`` |
