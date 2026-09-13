# Migrating to lossless numbers

Preserve JSON numeric precision and update code that used separate integer and double cases.

## Store a validated number token

`JSONValue` now stores every number in `.numberLiteral(JSONNumberLiteral)`. A number literal
retains its validated JSON token in `rawValue`; it does not have to fit `Int`, `Double`, or
Foundation `Decimal`.

```swift
import OrderedJSON

let amount = try JSONNumberLiteral("9.270")
let value = JSONValue.numberLiteral(amount)
print(try value.serialized()) // 9.270

let parsed = try JSONValue.parse("[9.270,-0,1e1000]")
print(try parsed.serialized()) // [9.270,-0,1e1000]
```

Use the throwing string initializer when source precision or spelling matters. It validates
JSON number syntax without surrounding whitespace, rejecting invalid tokens such as `NaN`,
`Infinity`, `01`, or `+1`.
`JSONValue.parse` and `serialized` preserve number tokens and object order, but not every
source detail: whitespace, string escape spellings, and duplicate members are not retained.

The stored literal is just its token: parsing and serialization do not allocate normalized
coefficient or exponent arrays. Numeric operations derive exact metadata when needed, using
machine-sized integers for common values and arbitrary-length decimal arithmetic otherwise.
This does not impose a machine-integer limit on accepted tokens.

## Update enum pattern matches

`.integer(Int)` and `.number(Double)` are now static convenience factories, not enum cases.
Construction remains familiar:

```swift
let count: JSONValue = .integer(42)
let estimate: JSONValue = .number(9.27)
let literal: JSONValue = 9.27
```

Replace `case .integer(let value)` and `case .number(let value)` with the single numeric case:

```swift
switch value {
case .numberLiteral(let number):
  print(number.rawValue)
  if number.isInteger {
    print("Mathematically integral")
  }
default:
  break
}
```

Swift integer and floating-point literals still work. Floating-point literals first become
`Double`, however, so they cannot preserve source digits already rounded by Swift or retain
spellings such as `9.270`. Construct `JSONNumberLiteral("9.270")` with `try` instead.

## Choose a conversion explicitly

| API | Behavior |
| --- | --- |
| `JSONNumberLiteral(String)` | Throws for invalid number tokens; retains accepted spelling. |
| `JSONNumberLiteral(Int)` | Nonthrowing, exact integer construction. |
| `JSONNumberLiteral(Double)` | Throwing construction from a finite double's decimal representation, not its original source text. |
| `JSONNumberLiteral(Decimal)` | Throwing construction from a Foundation decimal without passing through `Double`. |
| `integerValue()` | Throws unless the mathematical value fits `Int` exactly. |
| `doubleValue()` | Allows rounding to a finite `Double`; rejects overflow and nonzero values that underflow to zero. |
| `decimalValue()` | Returns an exact Foundation `Decimal`, or throws for an inexact or out-of-range conversion. |

`isInteger` describes mathematical integrality, not token syntax or `Int` range. `isZero`
also recognizes negative zero. For example, `1.0` and `1e2` are integers, and `-0` is zero.

The `JSONValue` accessors now follow those conversions:

- `primitive` returns `.integer` for any mathematical integer, including `1.0` and `1e2`.
- `integer` returns an exact `Int` for any numeric spelling, or `nil` for a nonnumber,
  fractional value, or value outside `Int` range.
- `number` and `numeric` return optional `Double` approximations for all numbers, including
  integers. They return `nil` for nonnumbers, overflow, or nonzero underflow.
- `numberLiteral` exposes the validated token without numeric conversion.

```swift
let value = try JSONValue.parse("1e2")
print(value.primitive == .integer) // true
print(value.integer == 100) // true
print(value.numberLiteral?.rawValue == "1e2") // true

let huge = try JSONValue.parse("1e1000")
print(huge.number == nil) // true; the token is still available
```

When callers need to distinguish conversion failure from missing or nonnumeric input,
inspect `numberLiteral` and use its throwing conversion methods.

## Reject non-finite inputs at construction

`.number(Double)` has a precondition that its argument is finite; it is not a throwing
validation API. For untrusted doubles, use `try JSONNumberLiteral(value)` and handle the
error before wrapping it in `.numberLiteral`.

`NonConformingFloatStrategy`, `SerializationError` (including `nonConformingFloat`), and
the `nonConformingFloatStrategy` serialization option have been removed. Invalid numbers
cannot reach the serializer. If your application represents non-finite data as JSON strings
or nulls, choose that representation explicitly.

## Compare mathematical values

`JSONNumberLiteral` equality, hashing, ordering, and `isMultiple(of:)` use exact mathematical
values rather than `Double` approximations. Thus `1`, `1.0`, and `1e0` compare and hash equally;
`-0` and `0` do too. Their `rawValue` strings and serialized tokens remain distinct.

`isMultiple(of:)` requires a strictly positive divisor; zero or negative divisors throw
`JSONNumberLiteral.ConversionError.nonPositiveDivisor`. General divisibility arithmetic is
limited to **4,096 significant coefficient digits per operand** and **1,000,000 decimal digit
work units**. Exceeding either limit throws `ConversionError.arithmeticResourceLimit` rather
than approximating. Trivial zero, unit-coefficient, equal-coefficient, and scale-rejection
cases can finish without that general arithmetic.

Equality, ordering, and integrality support arbitrary-length exponents without expanding
powers of ten. JSON Schema reports divisibility resource failures as
`ValidationIssue.numericValidationFailure`. Numeric comparisons and `multipleOf` use exact
values independently of a builder's destination Swift type.

Numeric evaluation failures are distinct from ordinary constraint mismatches.
`ValidationResult.isEvaluationComplete` is `false`, `isValid` is `false`, and
`evaluationErrors` contains the operational diagnostics. Applicators and references propagate
these failures rather than negating or discarding them: `not`, `if`, `anyOf`, `oneOf`, and
`contains` cannot turn exhausted arithmetic into success. Evaluation stops on the failure,
even if another branch could match, so the result never claims complete validation or
annotation collection. Invalid numeric constraints use the same failure path.
Native result JSON includes `evaluationErrors` when present. Structured output formats retain
`valid: false` and the available error details without adding nonstandard fields; flag output
is `false`.

## Keep Foundation Codable as a compatibility path

`JSONValue` and `JSONNumberLiteral` support `Codable`, but generic encoders and decoders work
with Swift numeric types, not raw JSON tokens.

With Foundation's `JSONEncoder`, a standalone `JSONNumberLiteral` encodes as a JSON number,
not a quoted `rawValue` string or a wrapper object. For example, a literal constructed from
`"1.0"` can encode as the JSON number `1`.

- Encoding tries an exact `Int`, then `Double` only if constructing `JSONNumberLiteral`
  from that double equals the original number, then an exact `Decimal`. Otherwise encoding
  throws `EncodingError`. Successful encoding still need not retain token spelling.
- Decoding prefers `Decimal`, accepting a decoded `Int` only when it agrees with that decimal.
  If the decoder cannot provide a decimal, it tries `Int`, then `Double`.
  A generic `Decoder` cannot supply the original token, and Foundation may round before the
  library sees the value. Original precision is therefore not guaranteed.

Use `JSONValue.parse` and `serialized` for token-preserving JSON I/O. This migration does
not add a complete custom `Codable` encoder or decoder.

## Schema and builder migration

`Schema(instance:)`, `parse(instance:)`, and `parseAndValidate(instance:)` use the lossless
parser by default. Overloads accepting an explicit `JSONDecoder` remain available but are
deprecated compatibility paths; omit `decoder:` to preserve number tokens.

`JSONInteger` returns an exact `Int`, `JSONNumber` returns a potentially rounded `Double`,
and `JSONDecimal` returns an exact Foundation `Decimal`. An otherwise valid JSON number can
fail typed parsing if the destination cannot represent it. `@Schemable` recognizes `Decimal`
and `Foundation.Decimal`, including optional properties and collection values.

Numeric constraints accept `JSONNumberLiteral` alongside their existing `Double` overloads,
including the `@NumberOptions` traits. Construct precise bounds from strings rather than Swift
floating-point literals. Numeric operands in `ValidationIssue` cases such as `exceedsMaximum`
and `notMultipleOf` use `JSONNumberLiteral`; inspect `rawValue` or explicitly convert instead
of assuming a `Double` payload.

Count constraints also compare exact literals: `minLength`, `maxLength`, `minItems`,
`maxItems`, `minProperties`, `maxProperties`, `minContains`, and `maxContains`. Their bounds
must be mathematical nonnegative integers, so `2.0` is accepted. A bound larger than `Int`
or `Double` can represent is not replaced with a permissive default. For example,
`"minItems": 1e1000` rejects an empty array. Public count/length `ValidationIssue` bound
payloads remain `Int`, as do actual counts and array indexes. Bounds are narrowed only when
reporting a failed constraint, after the exact comparison. If a failed bound cannot be
represented as `Int`, `numericValidationFailure` reports the exact bound in its reason
instead of clamping it or substituting a default.

See the [builder validation guide](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder/validation)
for examples of exact decimal parsing and constraints.
