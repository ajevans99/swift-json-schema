# Printing prototype

This draft explores the inverse of parsing: producing `JSONValue` from Swift
values without `Codable`. It borrows the additive parser-printer capability idea
from [swift-parsing](https://github.com/pointfreeco/swift-parsing), not its code
or unsafe memory-layout-based memberwise conversion.

## A struct round trip

```swift
struct Person {
  let name: String
  let age: Int
  let nickname: String?
}

let schema = JSONObject {
  JSONProperty(key: "name") { JSONString() }.required().printing { $0 }
  JSONProperty(key: "age") { JSONInteger().minimum(0) }.required().printing { $0 }
  JSONProperty(key: "nickname") { JSONString() }
}.map(Person.init, unapply: { ($0.name, $0.age, $0.nickname) })

let value: JSONValue = try schema.printAndValidate(person)
let restored: Person = try schema.parseAndValidate(value)
```

`JSONString`, `JSONInteger`, `JSONNumber`, `JSONBoolean`, and `JSONNull` support
printing. Arrays and property tuples support it when their elements do.
`print` constructs JSON; `printAndValidate` also checks the current schema,
including constraints such as `minimum`. Nonfinite doubles cannot be printed.
The result is a JSON value, not text. Existing JSON serialization remains a
separate operation.

The new `JSONSchemaPrinter` refinement preserves all parse-only APIs. A forward
`.map` or `.compactMap` does not gain an imaginary inverse. `.map(_:unapply:)`
requires both directions explicitly; a throwing inverse can reject outputs that
have no representation. It is the caller's responsibility to make these closures
obey the round-trip laws.

Required properties currently use a general `compactMap`, so the prototype
requires `.required().printing { $0 }` to supply that inverse. Optional properties
print `nil` as absence. A printable nullable value schema can return `.null` to
represent explicit null separately from a missing property. Duplicate property
names throw rather than silently overwrite a member.

## Existing schemas and macros

A parse-only component can gain printing through an explicit projection:

```swift
@Schemable
struct Person { let name: String }

let codec = Person.schema.printing { person in
  .object(["name": .string(person.name)])
}
let value = try codec.printAndValidate(Person(name: "Austin"))
```

This is intentionally **not automatic macro-derived printing** yet. Generating
safe projections from the macro's existing field plan is a promising follow-up,
but custom keys, exclusions, defaults, nullable fields, nested reference schemas,
and enum payloads need a deliberate policy and dedicated tests. This draft does
not change the existing macro expansion or silently claim that arbitrary
`Schemable` types are printable.

## Round-trip contract

For a lawful inverse and representable input, parsing a printed value should
recover the represented Swift fields. Explicit projections can omit fields, so
this need not recover an entire struct with excluded or defaulted state.

Printing a parsed document need not reproduce its original bytes or even all
members: unknown properties, absent/null distinctions deliberately collapsed by
the parser, key order, and number spelling may be lost. A conversion such as
integer-to-string can canonicalize `"01"` to `"1"`; the library cannot prove the
caller's inverse laws. Tests should cover the intended domain.

## Deliberate limits

- No automatic inversion of `flatMap`, arbitrary mappings, runtime schemas, or
  erased components.
- No implicit branch selection for `oneOf`/`anyOf` or enum printing.
- No automatic inverse of the existing `orNull` type-erasing modifier. Supply a
  projection when its null policy is intentional.
- No generated macro projection in this first draft.
- This branch uses the current String-keyed object representation. Scalar-exact
  Unicode key migration is separate work; canonical-equivalent keys are not
  preserved distinctly by this prototype.
- Error paths for nested array/property failures are not yet annotated. Original
  conversion errors propagate; schema validation errors retain their results.

The APIs and naming are experimental. Do not release or merge this draft as a
finished encoding feature.
