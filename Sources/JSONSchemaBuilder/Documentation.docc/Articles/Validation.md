# Parsing and validation

Turn JSON into Swift values while enforcing your schema's constraints.

## Choose the right operation

| Operation | Result | Use it when |
| --- | --- | --- |
| `component.parseAndValidate(value)` | Your Swift output, or a thrown ``ParseAndValidateIssue`` | Input must both satisfy the schema and convert to your model. |
| `component.definition().validate(value)` | `ValidationResult` | You need validity and diagnostics without constructing a Swift model. |
| `component.parse(value)` | ``Parsed`` with ``ParseIssue`` values on failure | You need conversion without independently enforcing every schema keyword. |

The `instance: String` parsing overloads also throw if JSON decoding fails. Primitive parsers
check JSON types, but `parse` alone is not a substitute for schema validation: for example,
`JSONString().minLength(5).parse(.string("hi"))` still produces a string.

## Map a builder into a Swift type

```swift
import JSONSchemaBuilder

struct Item {
  let name: String
  let price: Double
}

let itemSchema = JSONObject {
  JSONProperty(key: "name") {
    JSONString().minLength(1)
  }
  .required()

  JSONProperty(key: "price") {
    JSONNumber().minimum(0)
  }
  .required()
}
.map(Item.init)

let item: Item = try itemSchema.parseAndValidate(
  instance: #"{"name": "iPad", "price": 199.99}"#
)
print(item.name) // iPad
```

Object properties produce a tuple in declaration order. `.map(Item.init)` transforms that tuple
into a model; ``JSONSchema`` also accepts a transform and a builder closure. See <doc:WrapperTypes>
for other transformations, or <doc:Macros> to generate the builder from a Swift type.

Properties are optional unless marked `.required()`. Required means the key must be present;
whether its value may be `null` depends on the property's schema. Use `.orNull()` to accept
explicit nulls. Macro-generated schemas infer required and nullable behavior from Swift types.

Typed `.additionalProperties { ... }` returns only keys that are neither declared in `properties`
nor matched by `patternProperties`. Names such as `"type"` or `"properties"` in the input are
ordinary extra keys, not schema metadata. Failed additional-value parsing now rejects the object
instead of silently dropping those entries, including failures from nested models or enum keys.

## Handle invalid input

```swift
do {
  let item = try itemSchema.parseAndValidate(
    instance: #"{"name": "", "price": -1}"#
  )
  print(item)
} catch {
  switch error {
  case .decodingFailed(let underlying):
    print("Invalid JSON:", underlying)
  case .parsingFailed(let issues):
    print("Could not construct Item:", issues)
  case .validationFailed(let result):
    print("Schema constraints failed:", result.errors ?? [])
  case .parsingAndValidationFailed(let issues, let result):
    print("Parsing issues:", issues)
    print("Schema constraints failed:", result.errors ?? [])
  }
}
```

Schema diagnostics include keyword and instance locations. For machine-readable diagnostics,
use `result.renderedOutput(level: .basic)`; see the
[validation output guide](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema/validation-output-formats).

## Formats and ordered input

Enable format validation explicitly when your schema uses `format` constraints:

```swift
import JSONSchema

let context = Context(
  dialect: .draft2020_12,
  formatValidators: DefaultFormatValidators.all
)
let email = try JSONString().format("email").parseAndValidate(
  instance: #""ada@example.com""#,
  validationContext: context
)
```

The default context has no format validators. Custom implementations of `FormatValidator`
can be passed in the same registry.

String parsing overloads use `JSONValue.parse` by default, preserving source key order and
numeric tokens before conversion to your Swift output. You can also parse a `JSONValue`
yourself and pass it to `parseAndValidate` or `parse`. Overloads accepting an explicit
`JSONDecoder` remain available but are deprecated; Foundation decoding cannot guarantee
original number precision or spelling.

## Exact numbers and destination types

JSON numbers are stored as `.numberLiteral(JSONNumberLiteral)`, not `Double`. Numeric
validation compares mathematical values exactly, including `multipleOf`, independently of
the type returned by your builder. General `multipleOf` arithmetic has a bounded work budget;
exceeding it reports an explicit failure rather than approximating.

Typed parsing is a separate conversion step:

- `JSONInteger` accepts any mathematical integer that fits Swift `Int` exactly.
  Tokens such as `1.0` and `1e2` qualify; fractional and out-of-range values fail.
- `JSONNumber` returns `Double`, allowing rounding but rejecting overflow or nonzero values
  that underflow to zero.
- `JSONDecimal` returns Foundation `Decimal` without passing through `Double`. It rejects
  inexact and out-of-range conversions.

A valid JSON number such as `1e1000` can therefore pass schema validation but fail typed
parsing. `ParseIssue.numericConversionFailed` reports the target type and conversion reason.
Invalid JSON numbers, including non-finite inputs, are rejected before they enter the value tree.
Integral decimal keyword bounds such as `"minLength": 2.0` remain valid integer bounds.
Count constraints for lengths, items, properties, and `contains` matches compare those
bounds exactly. A bound outside `Int` or `Double` range does not fall back to a permissive
default; for example, `"minItems": 1e1000` still rejects an empty array.

```swift
import Foundation
import JSONSchemaBuilder

let cent = try JSONNumberLiteral("0.01")
let maximum = try JSONNumberLiteral("9999999999999999.99")
let price = JSONDecimal()
  .multipleOf(cent)
  .maximum(maximum)

let amount: Decimal = try price.parseAndValidate(instance: "9.270")
```

`minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, and `multipleOf` accept
`JSONNumberLiteral` as well as `Double`. Construct precise bounds from validated strings:
Swift floating-point literals have already been converted to `Double` and cannot recover
lost source digits. The `Double` overloads require finite inputs.

`@NumberOptions` supports the same exact-literal overloads, and `@Schemable` recognizes
`Decimal` and `Foundation.Decimal`, including optional properties and collection values.
See <doc:Macros> and the
[numeric migration guide](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/orderedjson/migrating-to-lossless-numbers)
for the enum-case and accessor changes.

## Composition parsing

Compositions validate each branch's schema before running its parser. Constraints such as
`minLength`, `pattern`, `const`, nested object requirements, and boolean schemas participate in
branch selection, even when multiple branches produce the same Swift type:

```swift
let text = JSONComposition.OneOf(into: String.self) {
  JSONString().minLength(5)
  JSONString().maxLength(3)
}
let value = try text.parseAndValidate(.string("hi")) // "hi", from the second branch
```

- `AnyOf` returns the first schema-valid branch whose parser succeeds, in declaration order.
- `OneOf` requires exactly one branch that is both schema-valid and successfully parsed.
- `AllOf` requires every branch to validate and parse successfully, and returns the first branch's
  output. It does not merge object fields or Swift outputs.
- `Not` rejects a value when its branch both validates and parses successfully.

Mappings still transform the selected output. A custom parser or `compactMap` can reject an
otherwise schema-valid branch. For example, direct `OneOf.parse` can have one successful parser
even though two JSON schemas match; `parseAndValidate` still rejects that instance as ambiguous.
Similarly, a custom parsing failure inside `Not` does not override the complete schema's verdict.
Schema failures are reported as nested `ParseIssue.runtimeValidationIssue` values, retaining
keyword and instance locations.

### Validation context and projections

`parseAndValidate` evaluates the complete schema before parsing and reuses its branch results.
Nested properties, array items, nullable unions, and typed references retain the caller's format
validators, remote schemas, enclosing definitions, identifiers, vocabulary, and dynamic-reference
scope. Direct composition, object, and array parsing uses a default draft 2020-12 context; pass
`validationContext` to `parseAndValidate` when external schemas or custom formats are needed.
Each `parseAndValidate` call copies the context's configuration into a fresh evaluation context.
It does not mutate the caller's schema caches, registered documents, or dynamic scopes, and
reusing a context does not reuse an earlier call's root definitions.

Custom components, `flatMap`, and type-erased components can parse a shape different from their
emitted `schemaValue`, such as an object projection of `allOf`. Unmatched, self-contained branches
are evaluated separately with the caller's dialect and format validators, while the original full
schema remains authoritative. This does not add field merging to `AllOf`.

A projected branch containing `$ref` or `$dynamicRef`, or a projection under a custom vocabulary,
requires a matching position and branch schema in the original validation tree. Otherwise parsing
reports that branch validation is unavailable, rather than guessing a reference scope or using
default validation options. Keep the parsing and emitted schema structures aligned, inline the
references, or opt into the static projection boundary described below.

This also applies when a projection hides a branch's own custom vocabulary. Typed reference parsers
only reuse evaluations belonging to their emitted reference schema; an unmatched reference cannot
borrow another target's results or independently validate its nested compositions.

### Explicit static projections

Use ``JSONComponents/Projection`` when a typed parser intentionally has a different shape from
the complete schema, including reference-bearing compositions. This is useful for generated
models whose parser merges `allOf` fields or represents a type array as an `AnyOf`.

```swift
struct Name: Schemable {
  let value: String
  static var schema: some JSONSchemaComponent<Name> {
    JSONString().map { Name(value: $0) }
  }
}

enum Value {
  case name(Name)
  case flag(Bool)
}

let parser = JSONComposition.AnyOf(into: Value.self) {
  JSONReference<Name>.definition(named: "name").map { Value.name($0) }
  JSONBoolean().map { Value.flag($0) }
}
let complete: SchemaValue = [
  "$defs": ["name": ["type": "string"]],
  "allOf": [parser.schemaValue.value],
]
let projection = JSONComponents.Projection(upstream: parser, schemaValue: complete)
let value = try projection.parseAndValidate(.string("hello"))
```

The equivalent modifier is `parser.projection(schemaValue: complete)`. Both retain the parser's
`Output`. The projection's mutable `schemaValue` is the exact complete validation schema;
the wrapper does not rewrite it or add a validation keyword. `parseAndValidate` requires both
the complete schema and the typed parser to succeed. Plain `parse` still does not enforce every
keyword of the complete schema.

Parsing evaluates the parser's own schema in an isolated context using the caller's format
validators. Root `$defs` from the enclosing document, complete schema, and parser are combined
for parsing only. This definition environment follows nested projections under properties,
arrays, and compositions, and through recursive `JSONReference<T>` targets. Equal definitions
may be repeated; conflicting names fail explicitly instead of shadowing. A top-level projection
must carry the full definition bundle, while nested projections may inherit it.

This boundary supports standard draft 2020-12 and static, self-contained `#/$defs/...` pointers
without percent encoding. Unresolved references, remote references, dynamic references, and
custom vocabulary declarations are rejected. Standard vocabulary subsets must include core,
applicator, and validation; omitted format, unevaluated, or content vocabularies must not have
keywords anywhere in the bundle. This prevents enabling assertions that the complete schema
deliberately disables. Declaring all seven standard 2020-12 vocabularies is supported.
Identifiers (`$id`) and anchors (`$anchor`, `$dynamicAnchor`) are allowed only when the bundle has no
references; reference-bearing bundles must remove them and resolve any dynamic scope before
projection. These checks traverse schema keywords and reference targets, not arbitrary instance
data in `const`, `enum`, `default`, `examples`, or extension annotations. Caller overrides of
the standard dialect's vocabulary also require the full standard vocabulary set.

The legacy `$recursiveRef` and `$recursiveAnchor` keywords are reserved but inert in draft
2020-12. Projections preserve their raw values, including in unused definitions, without resolving
them, traversing their values as schemas, or treating them as identifiers. In particular,
`"$recursiveRef": "#"` does not enable recursion. A `oneOf` branch containing only that keyword
matches every instance: an instance matching another branch therefore fails `oneOf`, while an
instance matching no other branch can pass. Projection preserves these literal validation
semantics; it does not repair schemas authored with legacy recursion intent. Explicit non-2020-12
`$schema` declarations remain unsupported, as does actual `$dynamicRef` evaluation in a static
projection bundle.

Unsupported scopes, conflicting definitions, malformed parsing bundles, and parsing-schema
construction failures produce `ParseIssue.projectionFailure` rather than silently changing
reference scope or falling back to a default schema. The existing safety refusal still applies
to arbitrary type-erased or custom parsers that do not explicitly preserve their parsing schema.
