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
- **Numbers** are stored as `.numberLiteral(JSONNumberLiteral)` with their original token.
  Fractional digits, trailing zeros, a negative-zero sign, and exponent spelling are retained;
  values such as `1e1000` need not fit `Int`, `Double`, or Foundation `Decimal`.
- **Duplicate keys** are accepted; the **last** occurrence wins on both *value* and *position* — the late-bound key occupies the trailing position in the resulting object.
- **UTF-16 surrogate pairs in `\u` escapes** are decoded into single Unicode scalars.
- **The byte stream must be valid UTF-8**. UTF-16 / UTF-32 / BOMs are rejected.

## Number tokens and numeric types

```swift
let value = try JSONValue.parse("[9.270,-0,1e1000]")
print(try value.serialized()) // [9.270,-0,1e1000]

let integral = try JSONValue.parse("1e2")
print(integral.primitive == .integer) // true
print(integral.integer == 100) // true
```

`primitive` classifies numbers mathematically: `1.0` and `1e2` are integers even though their
tokens contain a decimal point or exponent. The original token remains unchanged. Conversion
to a destination Swift type is a separate step and can fail if the value is out of range.
See <doc:Migrating-to-lossless-numbers> for exact and approximate conversions.

Number-token preservation does not retain source whitespace, string escape spellings, or
duplicate object members. It is not a byte-for-byte source archive.

## Limits

The parser accepts nested objects and arrays up to **256 levels**, using an explicit container stack rather than recursive parsing. A scalar leaf adds no container depth. Opening a container at level 257 throws ``JSONParseError`` with `Maximum nesting depth (256) exceeded`; the error offset points just after that opening delimiter. This limit is the same for `String` and `Data` input.

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
| Exact numbers and original numeric token spellings | `OrderedJSON.JSONValue.parse` |
| RFC-8259-strict parsing (no trailing commas, no comments) | `OrderedJSON.JSONValue.parse` |
| Round-trip byte-stable JSON (parse → emit → parse → emit) | `OrderedJSON.JSONValue.parse` + ``JSONValue/serialized(options:)`` |
